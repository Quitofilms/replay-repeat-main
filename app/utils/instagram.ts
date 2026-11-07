/**
 * Instagram has no player API, so this app cannot seek or loop its videos.
 * A link from Instagram gets a message that says how to get the file instead.
 */
export function isInstagramLink(text: string): boolean {
  const input = text.trim();

  try {
    const url = new URL(input.includes("://") ? input : `https://${input}`);
    const host = url.hostname.replace(/^(www|m)\./, "");

    return host === "instagram.com" || host === "instagr.am";
  } catch {
    return false;
  }
}
