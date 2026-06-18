import { isNumber, isString } from "jsr:@core/unknownutil";
import type { Denops } from "jsr:@denops/std";
import {
  commitgen,
  type CommitMessage,
  getStagedDiff,
} from "jsr:@gw31415/commitgen";

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
          // Forward progress event to Vim/Lua side for UI rendering
          try {
            await denops.call("commitgen#progress", event);
          } catch {
            // Ignore progress callback errors (e.g. during batch mode)
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
