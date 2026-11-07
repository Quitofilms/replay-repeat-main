import type { QueryParams } from "#services/url-state.ts";

/**
 * The query params that hold the state of the app,
 * so a link opens the same video with the same loop and speed.
 *
 * A file from disk cannot be in a URL. An uploaded Drive file uses its ID,
 * and saved replay links may also include a title and note.
 */
export const PARAMS = {
  youtube: "youtube_video_id",
  drive: "drive_file_id",
  title: "saved_title",
  note: "saved_note",
  loopStart: "loop_start",
  loopEnd: "loop_end",
  loop: "loop",
  speed: "speed",
} as const;

/**
 * A new video clears its loop, saved title, note, and Drive source.
 * The speed stays, because it is about the person, not the video.
 */
export const NEW_VIDEO: QueryParams = {
  [PARAMS.loopStart]: null,
  [PARAMS.loopEnd]: null,
  [PARAMS.loop]: null,
  [PARAMS.drive]: null,
  [PARAMS.title]: null,
  [PARAMS.note]: null,
};

/**
 * Seconds from a param. Anything that is not a time is ignored.
 */
export function secondsOf(value: string | undefined): number | undefined {
  if (value === undefined) return;

  const seconds = Number.parseFloat(value);

  return Number.isFinite(seconds) && seconds >= 0 ? seconds : undefined;
}

/**
 * Seconds for a param, in tenths, as the markers move: `3.5`, not `3.5000000001`.
 */
export function formatSeconds(seconds: number): string {
  return String(Number(seconds.toFixed(1)));
}
