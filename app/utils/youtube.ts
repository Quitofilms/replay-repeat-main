const ID = /^[\w-]{11}$/;

/**
 * Finds the video id in what a user pastes:
 *
 * - a bare id, `dQw4w9WgXcQ`
 * - `youtube.com/watch?v=<id>`, also on `m.` and `music.`
 * - `youtube.com/shorts/<id>`, `/embed/<id>`, `/live/<id>`
 * - `youtu.be/<id>`
 */
export function youTubeIdOf(text: string): string | undefined {
  const input = text.trim();

  if (ID.test(input)) return input;

  let url: URL;

  try {
    url = new URL(input.includes("://") ? input : `https://${input}`);
  } catch {
    return undefined;
  }

  const host = url.hostname.replace(/^(www|m|music)\./, "");
  const parts = url.pathname.split("/");
  let id: string | null | undefined;

  if (host === "youtu.be") {
    id = parts[1];
  } else if (host === "youtube.com" || host === "youtube-nocookie.com") {
    id =
      parts[1] === "shorts" || parts[1] === "embed" || parts[1] === "live"
        ? parts[2]
        : url.searchParams.get("v");
  }

  return id && ID.test(id) ? id : undefined;
}

let api: Promise<typeof YT> | undefined;

/**
 * Loads the YouTube IFrame Player API once.
 *
 * This is the only way to control an embedded YouTube video,
 * so it is the one script that this app loads from another site.
 */
export function loadYouTubeApi(): Promise<typeof YT> {
  api ??= new Promise((resolve, reject) => {
    const previous = window.onYouTubeIframeAPIReady;

    window.onYouTubeIframeAPIReady = () => {
      previous?.();
      resolve(YT);
    };

    const script = document.createElement("script");

    script.src = "https://www.youtube.com/iframe_api";
    script.async = true;

    script.onerror = () => {
      api = undefined;
      script.remove();
      reject(new Error("The YouTube player did not load. Check the network connection."));
    };

    document.head.append(script);
  });

  return api;
}

declare global {
  interface Window {
    onYouTubeIframeAPIReady?: () => void;
  }
}
