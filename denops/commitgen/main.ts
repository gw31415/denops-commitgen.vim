import { isNumber, isString } from "jsr:@core/unknownutil";
import type { Denops } from "jsr:@denops/std";
import {
  commitgen as originCommitgen,
  getStagedDiff,
} from "jsr:@gw31415/commitgen";

export function main(denops: Denops) {
  denops.dispatcher = {
    commitgen(model, cwd, count, apiKey = null) {
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
      return originCommitgen({
        model: model as any,
        count,
        cwd,
        apiKey: apiKey ?? undefined,
      });
    },
    getStagedDiff(cwd) {
      if (!isString(cwd)) {
        throw new Error("cwd must be a string");
      }
      return getStagedDiff(cwd);
    },
  };
}
