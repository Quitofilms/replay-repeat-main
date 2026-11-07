import { tracked } from "@glimmer/tracking";

/**
 * Undo and redo for a value that changes in steps.
 *
 * The owner changes its value freely, for example on every step of a drag,
 * and calls `record` when a change is done. Only recorded values are undo steps.
 */
export class History<T> {
  @tracked past: T[] = [];
  @tracked future: T[] = [];

  #present: T;
  #isSame: (a: T, b: T) => boolean;

  constructor(present: T, isSame: (a: T, b: T) => boolean) {
    this.#present = present;
    this.#isSame = isSame;
  }

  get canUndo() {
    return this.past.length > 0;
  }

  get canRedo() {
    return this.future.length > 0;
  }

  /**
   * A new value clears the redo steps, as in a text editor.
   */
  record(value: T) {
    if (this.#isSame(value, this.#present)) return;

    this.past = this.past.concat([this.#present]);
    this.future = [];
    this.#present = value;
  }

  /**
   * Returns the value to go back to.
   */
  undo(): T | undefined {
    const previous = this.past.at(-1);

    if (previous === undefined) return;

    this.past = this.past.slice(0, -1);
    this.future = this.future.concat([this.#present]);
    this.#present = previous;

    return previous;
  }

  /**
   * Returns the value to go forward to.
   */
  redo(): T | undefined {
    const next = this.future.at(-1);

    if (next === undefined) return;

    this.future = this.future.slice(0, -1);
    this.past = this.past.concat([this.#present]);
    this.#present = next;

    return next;
  }
}
