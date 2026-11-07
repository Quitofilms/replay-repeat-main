export type Source = { kind: "file"; file: File } | { kind: "youtube"; id: string } | { kind: "drive"; id: string; downloadUrl?: string };

/**
 * A browser takes the type of a file from the operating system,
 * which may not know some formats, such as `.mkv`, and gives an empty type.
 * The file picker lists these extensions too, so it does not hide such files.
 */
const MEDIA_EXTENSIONS = [
  ".mp4",
  ".m4v",
  ".mov",
  ".mkv",
  ".webm",
  ".ogv",
  ".avi",
  ".mp3",
  ".m4a",
  ".aac",
  ".wav",
  ".flac",
  ".ogg",
  ".oga",
  ".opus",
];

/**
 * The files that the browser can play, as an `accept` list for the file picker.
 */
export const MEDIA_FILES = `video/*,audio/*,${MEDIA_EXTENSIONS.join(",")}`;

/**
 * A file with no type gets a try: if the browser cannot play it,
 * the player says so. Only a file with another type, such as text, is refused.
 */
export function isMedia(file: File): boolean {
  return file.type === "" || file.type.startsWith("video/") || file.type.startsWith("audio/");
}

export function fileSource(files: File[]): Source | undefined {
  const file = files[0];

  return file ? { kind: "file", file } : undefined;
}
