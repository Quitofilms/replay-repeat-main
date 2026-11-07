interface SavedLinkBase {
  id: string;
  title: string;
  note: string;
  savedAt: number;
  videoId?: string;
  fileId?: string;
  fileName?: string;
  fileType?: string;
}

export type SavedLink =
  | (SavedLinkBase & { kind: "youtube"; videoId: string })
  | (SavedLinkBase & { kind: "local"; fileId: string; fileName: string; fileType: string });
interface StoredVideo {
  id: string;
  name: string;
  type: string;
  lastModified: number;
  blob: Blob;
}

const DATABASE = "replay-repeat-handout";
const VERSION = 1;
let opening: Promise<IDBDatabase> | undefined;

function openDatabase(): Promise<IDBDatabase> {
  if (!("indexedDB" in window)) {
    return Promise.reject(new Error("This browser does not support local video storage."));
  }

  opening ??= new Promise((resolve, reject) => {
    const request = indexedDB.open(DATABASE, VERSION);

    request.onupgradeneeded = () => {
      const database = request.result;

      if (!database.objectStoreNames.contains("links")) {
        database.createObjectStore("links", { keyPath: "id" });
      }
      if (!database.objectStoreNames.contains("videos")) {
        database.createObjectStore("videos", { keyPath: "id" });
      }
    };
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => {
      opening = undefined;
      reject(request.error ?? new Error("Could not open this browser's saved library."));
    };
    request.onblocked = () => {
      opening = undefined;
      reject(new Error("Close other Replay, repeat tabs and try again."));
    };
  });

  return opening;
}

function transactionDone(transaction: IDBTransaction): Promise<void> {
  return new Promise((resolve, reject) => {
    transaction.oncomplete = () => resolve();
    transaction.onerror = () =>
      reject(transaction.error ?? new Error("The browser could not save this item."));
    transaction.onabort = () =>
      reject(transaction.error ?? new Error("The browser cancelled this save."));
  });
}

function requestResult<T>(request: IDBRequest<T>): Promise<T> {
  return new Promise((resolve, reject) => {
    request.onsuccess = () => resolve(request.result);
    request.onerror = () =>
      reject(request.error ?? new Error("The browser could not read this item."));
  });
}

export async function getSavedLinks(): Promise<SavedLink[]> {
  const database = await openDatabase();
  const transaction = database.transaction("links", "readonly");
  const result = await requestResult<SavedLink[]>(transaction.objectStore("links").getAll());

  return result.sort((a, b) => b.savedAt - a.savedAt);
}

export async function saveLink(link: SavedLink, file?: File): Promise<void> {
  const database = await openDatabase();
  const transaction = database.transaction(["links", "videos"], "readwrite");

  if (file && link.kind === "local") {
    const video: StoredVideo = {
      id: link.fileId,
      name: file.name,
      type: file.type,
      lastModified: file.lastModified,
      blob: file.slice(0, file.size, file.type),
    };
    transaction.objectStore("videos").put(video);
  }

  transaction.objectStore("links").put(link);
  await transactionDone(transaction);
}

export async function getSavedVideo(id: string): Promise<File | undefined> {
  const database = await openDatabase();
  const transaction = database.transaction("videos", "readonly");
  const stored = await requestResult<StoredVideo | undefined>(
    transaction.objectStore("videos").get(id),
  );

  if (!stored) return undefined;

  return new File([stored.blob], stored.name, {
    type: stored.type,
    lastModified: stored.lastModified,
  });
}

export async function removeLink(link: SavedLink): Promise<void> {
  const database = await openDatabase();
  const transaction = database.transaction(["links", "videos"], "readwrite");

  transaction.objectStore("links").delete(link.id);
  if (link.kind === "local") transaction.objectStore("videos").delete(link.fileId);
  await transactionDone(transaction);
}

export async function importLinks(links: SavedLink[]): Promise<void> {
  const database = await openDatabase();
  const transaction = database.transaction("links", "readwrite");
  const store = transaction.objectStore("links");

  for (const link of links) store.put(link);

  await transactionDone(transaction);
}

export function isSavedLink(value: unknown): value is SavedLink {
  if (!value || typeof value !== "object") return false;

  const link = value as Record<string, unknown>;
  if (
    typeof link.id !== "string" ||
    typeof link.title !== "string" ||
    typeof link.note !== "string" ||
    typeof link.savedAt !== "number"
  ) {
    return false;
  }

  if (link.kind === "youtube") {
    return typeof link.videoId === "string" && /^[\w-]{11}$/.test(link.videoId);
  }

  return (
    link.kind === "local" &&
    typeof link.fileId === "string" &&
    typeof link.fileName === "string" &&
    typeof link.fileType === "string"
  );
}