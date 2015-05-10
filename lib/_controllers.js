/**
 * @author Krzysztof Winiarski
 * @copyright (c) 2014 Krzysztof Winiarski
 * @license MIT
 */

'use strict';

var _ = require('lodash')
  , CONFIG = require('../config')
  , support = require('./support')
  , models = require('./../models')
  , blueprints = require('./blueprints')
  , config = require(CONFIG.CONTROLLERS_CONFIG)
  , controllers = support.loadModules(CONFIG.CONTROLLERS_DIR)
  , eventsLog = require('./log/events')
  , replacedActions = {};





function parseActionName(name) {
  return name.replace(/\B[A-Z]/g, function(match){
    return '-' + match;
  }).toLowerCase();
}

function toLowerCase(str) {
  return str.toLowerCase();
}

function responseStrategy(res, method) {
  switch (method) {
    case 'post': return res.created;
    case 'get': return res.okOrNotFound;
    case 'put': return res.createdOrNoContent;
    case 'delete': return res.noContent;

  }
}

function wrapAction(actionFn) {

  if (actionFn.wrapped === true) {
    return actionFn;
  }

  function wrappedAction(req, res, next) {
    var result = actionFn(req, res, next);

    if (res.headersSent === true) {
      eventsLog.error('Headers already send.');
      return;
    }

    if (!result) {
      return;
    }

    if (typeof result.then === 'function') {
      var method = req.method.toLowerCase()
        , success = responseStrategy(res, method);

      return result
        .then(success)
        .catch(res.error);
    } else {
      eventsLog.error('Action output is not a Promise instance.'
        + ' Action should return Promise or undefined. If Promise is returned and response was send'
        + ' within action function headers may be send twice.', {
        method: req.method,
        url: req.originalUrl || req.url
      });
    }
  }

  wrappedAction.wrapped = true;
  return wrappedAction;
}

for (var ctrlName in controllers) {

  var controller = require(controllers[ctrlName].file)
    , settings = config[ctrlName] || {}
    , action
    , actionSettings;

  for (action in controller) {
    actionSettings = settings[action] || {};
    controller[action] = {
      methods: (actionSettings.methods || ['get']).map(toLowerCase),
      route: actionSettings.route || blueprints.routes[action] || '/' + parseActionName(action),
      fn: wrapAction(controller[action])
    };
  }

  controllers[ctrlName] = controller;
  eventsLog.debug('controller initialized', ctrlName);
}

for (var modelName in models) {

  replacedActions[modelName] = {};

  if (!controllers[modelName]) {
    controllers[modelName] = {};
  }

  var model = models[modelName]
    , controller = controllers[modelName]
    , actionName
    , blueprint = blueprints.getDefaultActions(model, modelName);

  for (actionName in blueprint) {
    if (!controller[actionName]) {
      controller[actionName] = blueprint[actionName];
      controller[actionName].fn = wrapAction(controller[actionName].fn);
    } else {
      // Overwritten blueprint action should be still available under
      // blueprint route, however with new callback function.
      replacedActions[modelName][actionName] = {
        route: blueprint[actionName].route,
        methods: blueprint[actionName].methods,
        fn: controller[actionName].fn
      };
    }
  }
}

module.exports = controllers;

Object.defineProperty(module.exports, '_replaced', {
  value: replacedActions,
  enumerable: false
});