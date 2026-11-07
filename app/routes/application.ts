import Route from "@ember/routing/route";

import { PARAMS } from "#utils/params.ts";

/**
 * Declares the query params, with no controller,
 * so that `router.transitionTo({ queryParams })` writes them to the URL.
 * Without this, the router keeps them in `currentRoute.queryParams` only.
 *
 * The `url-state` service reads and writes them. None of them loads data.
 */
export default class ApplicationRoute extends Route {
  queryParams = {
    [PARAMS.youtube]: { refreshModel: false },
    [PARAMS.loopStart]: { refreshModel: false },
    [PARAMS.loopEnd]: { refreshModel: false },
    [PARAMS.loop]: { refreshModel: false },
    [PARAMS.speed]: { refreshModel: false },
  };
}
