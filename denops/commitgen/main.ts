import { isNumber, isString } from "jsr:@core/unknownutil";
import type { Denops } from "jsr:@denops/std";
import {
  commitgen,
  type CommitgenEvent,
  type CommitMessage,
  getStagedDiff,
} from "jsr:@gw31415/commitgen";

function formatProgress(event: CommitgenEvent): string {
  switch (event.type) {
    case "info":
      return event.strategy === "inline"
        ? `Analyzing diff (${event.diffBytes} bytes)...`
        : `Analyzing diff (${event.diffBytes} bytes) in ${event.chunkCount} chunks...`;
    case "map_progress":
      return `Summarizing chunk ${event.current}/${event.total}...`;
    case "reduce_start":
      return "Generating commit messages...";
    case "result":
      return "";
  }
}

export function main(denops: Denops) {
  denops.dispatcher = {
    async commitgen(model, cwd, count, apiKey = null, baseURL = null) {
      if (!isString(model)) {
        throw new Error("model must be a string");
      }
      if (!isNumber(count)) {
        throw new Error("count must be a number");
      }
      if (!isString(cwd)) {
        throw new Error("cwd must be a string");
      }
      if (apiKey !== null && !isString(apiKey)) {
        throw new Error("apiKey must be a string or null");
      }
      if (baseURL !== null && !isString(baseURL)) {
        throw new Error("baseURL must be a string or null");
      }

      let result: CommitMessage[] = [];
      for await (
        const event of commitgen({
          model,
          count,
          cwd,
          apiKey: apiKey ?? undefined,
          baseURL: baseURL ?? undefined,
        })
      ) {
        if (event.type === "result") {
          result = event.messages;
        } else {
          const msg = formatProgress(event);
          if (msg) {
            try {
              await denops.cmd(
                `echomsg '[commitgen] ${msg.replace(/'/g, "''")}'`,
              );
            } catch {
              // Ignore echo errors (e.g. during batch mode)
            }
          }
        }
      }
      return result;
    },
    getStagedDiff(cwd) {
      if (!isString(cwd)) {
        throw new Error("cwd must be a string");
      }
      return getStagedDiff(cwd);
    },
  };
}
