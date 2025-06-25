import OpenAI from "jsr:@openai/openai";
import Ajv, { type JSONSchemaType } from "npm:ajv";
import { encoding_for_model, type TiktokenModel } from "npm:tiktoken";

interface CommitMessage {
  commitMsgContent: string;
  conventionalCommitType:
    | "feat"
    | "fix"
    | "docs"
    | "style"
    | "refactor"
    | "perf"
    | "test"
    | "build"
    | "ci"
    | "chore"
    | "revert";
}

interface Attachments {
  vectorStoreId: string;
  fileId: string;
}

const commitMessagesSchema: (c: number) => JSONSchemaType<CommitMessage[]> = (
  count,
) => ({
  type: "array",
  items: {
    type: "object",
    properties: {
      commitMsgContent: {
        type: "string",
        description:
          "Commit message content, without the Conventional Commit type tag.",
      },
      conventionalCommitType: {
        type: "string",
        description: "One of the Conventional Commit types.",
        enum: [
          "feat",
          "fix",
          "docs",
          "style",
          "refactor",
          "perf",
          "test",
          "build",
          "ci",
          "chore",
          "revert",
        ],
      },
    },
    required: ["commitMsgContent", "conventionalCommitType"],
    additionalProperties: false,
  },
  minItems: count,
});

interface CommitgenOptions {
  count: number;
  cwd: string;
  model: TiktokenModel & OpenAI.ResponsesModel;
}

const inlineDiffTokenLimit = 4096;

export async function commitgen(
  options: CommitgenOptions,
): Promise<CommitMessage[]> {
  const model = options.model;

  function countTokens(text: string): number {
    const enc = encoding_for_model(model);
    try {
      return enc.encode(text).length;
    } finally {
      enc.free();
    }
  }

  // Get staged diff
  const diffCmd = new Deno.Command("git", {
    args: ["diff", "--cached", "--ignore-all-space"],
    cwd: options.cwd,
    stdout: "piped",
    stderr: "piped",
  });
  const diffProcess = diffCmd.spawn();
  const { stdout } = await diffProcess.output();
  const diff = new TextDecoder().decode(stdout);
  if (!diff.trim()) {
    throw new Error("No staged changes found.");
  }

  const openai = new OpenAI({
    apiKey: Deno.env.get("OPENAI_API_KEY"),
  });
  let attachments: Attachments | null = null;

  try {
    if (countTokens(diff) > inlineDiffTokenLimit) {
      try {
        const file = new File([diff], "diff.txt", { type: "text/plain" });
        const uploaded = await openai.files.create({
          file,
          purpose: "user_data",
        });
        const fileId = uploaded.id;

        const vectorStore = await openai.vectorStores.create({
          name: "commitgen-diff",
          expires_after: { anchor: "last_active_at", days: 1 },
        });
        const newAttachments: Attachments = {
          vectorStoreId: vectorStore.id,
          fileId,
        };
        attachments = newAttachments;
        await openai.vectorStores.files.create(newAttachments.vectorStoreId, {
          file_id: newAttachments.fileId,
        });
        // Wait for file indexing to complete
        let fileStatus = "";
        for (let i = 0; i < 20; i++) { // up to ~10 seconds
          const fileList = await openai.vectorStores.files.list(
            newAttachments.vectorStoreId,
          );
          const fileEntry = fileList.data.find((f) =>
            f.id === newAttachments.fileId
          );
          fileStatus = fileEntry?.status || "";
          if (fileStatus === "completed") break;
          if (fileStatus === "failed") {
            throw new Error("File indexing failed in vector store");
          }
          await new Promise((res) => setTimeout(res, 500));
        }
        if (fileStatus !== "completed") {
          throw new Error("File indexing did not complete in time");
        }
      } catch (e) {
        throw new Error(
          "Failed to create vector store or attach file: " +
            (e instanceof Error ? e.message : String(e)),
        );
      }
    }

    // Call Responses API with file_search tool
    const instructions =
      `You are a commit message generator. Given the given diff.txt, propose commit message candidates as function calls.\n` +
      "Each commit message MUST represent the COMPLETE of diff.txt by itself. It is not acceptable to mention only part of the change.";

    const tools: OpenAI.Responses.Tool[] = attachments
      ? [{
        type: "file_search",
        vector_store_ids: [attachments.vectorStoreId],
      }]
      : [];
    tools.push(
      {
        type: "function",
        name: "propose_commit_message",
        description:
          "Propose commit messages for a git diff, separating the conventional commit type and the message content.",
        parameters: {
          type: "object",
          properties: {
            args: commitMessagesSchema(options.count),
          },
          required: ["args"],
          additionalProperties: false,
        },
        strict: true,
      },
    );

    const response = await openai.responses.create({
      model,
      instructions,
      input:
        `Please analyze the diff.txt and generate ${options.count} commit message candidates.` +
        (attachments ? "" : "\n\n```diff.txt\n" + diff + "\n```"),
      tools,
    });

    const outputs = response.output.filter((i) => i.type === "function_call")
      .map(
        (i) => i.arguments,
      );

    const output = outputs.flatMap((i) => JSON.parse(i)?.args ?? []);

    // Validate output
    const ajv = new Ajv.default();
    const validate = ajv.compile(commitMessagesSchema(options.count));
    if (!validate(output)) {
      throw new Error(
        "OpenAI response did not match schema: " +
          JSON.stringify(validate.errors),
      );
    }

    return output.slice(0, options.count);
  } finally {
    if (attachments) {
      try {
        await openai.files.delete(attachments.fileId);
      } catch (e) {
        console.error("Failed to delete file:", e);
      }
      try {
        await openai.vectorStores.delete(attachments.vectorStoreId);
      } catch (e) {
        console.error("Failed to delete vector store:", e);
      }
    }
  }
}
