/**
 * @author Krzysztof Winiarski
 * @copyright (c) 2014 Krzysztof Winiarski
 * @license MIT
 */

'use strict';

var Resource = require('../lib/resource')
  , policies = require('../lib/policy')
  , models = require('../models')
  , RequestError = require('../lib/errors').RequestError
  , controllers = require('../lib/controllers')
  , router = require('express').Router()
  , resources = {};

function registerResourceComponent(name, object) {
  for (var i in object) {
    if (!resources[i]) {
      resources[i] = {};
    }

    resources[i][name] = object[i];
  }
}

registerResourceComponent('model', models);
registerResourceComponent('controller', controllers);

for (var i in resources) {
  resources[i] = new Resource(resources[i].model, resources[i].controller, policies);
  router.use(resources[i].getRouter());

}
// TODO Add 404 support
router.use(function(req, res, next){
  next(RequestError.NotFound());
});

// TODO Add 500 support

module.exports = router;
