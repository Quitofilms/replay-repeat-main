/**
 * Formats seconds with tenths, because loops are often shorter than a second:
 *
 *   5.25 → 0:05.3
 *   65 → 1:05.0
 *   3725.5 → 1:02:05.5
 */
export function formatTime(seconds: number): string {
  const tenths = Math.round(Math.max(seconds, 0) * 10);
  const hours = Math.floor(tenths / 36000);
  const minutes = Math.floor((tenths % 36000) / 600);
  const rest = ((tenths % 600) / 10).toFixed(1).padStart(4, "0");

  if (hours > 0) {
    return `${hours}:${String(minutes).padStart(2, "0")}:${rest}`;
  }

  return `${minutes}:${rest}`;
}
