/* Portal SDK mock helpers shared by browser QA; production shell initializes SDKs inline. */
(function (root) {
  "use strict";
  root.RackPortalTest = {
    safely: function (promise) {
      return Promise.resolve(promise).then(function () { return true; }).catch(function () { return false; });
    },
    isHost: function (target, hostname, referrer) {
      if (target) return target;
      var host = (hostname + " " + referrer).toLowerCase();
      if (host.indexOf("poki") !== -1) return "poki";
      if (host.indexOf("crazygames") !== -1) return "crazygames";
      if (host.indexOf("coolmathgames") !== -1 || host.indexOf("coolmath") !== -1) return "coolmath";
      return "local";
    }
  };
}(typeof window !== "undefined" ? window : globalThis));
