'use strict';

var chai = require('chai');
var utils = require('chai/lib/chai/utils');
var mockery = require('mockery');
var Bluebird = require('bluebird');

/* jshint -W030 */
utils.addMethod(chai.Assertion.prototype, 'readOnly', function (property) {
  var descriptor = Object.getOwnPropertyDescriptor(this._obj, property);
  new chai.Assertion(descriptor.writable).to.be.false;
});
utils.addMethod(chai.Assertion.prototype, 'memberFunctions', function (members) {
  var check = true;
  for (var i = 0, j = members.length; i < j; i++) {
    check = check
      && typeof members[i] === 'function'
      && typeof this._obj[i] === 'function'
      && members[i].toString() === this._obj[i].toString();
  }
  new chai.Assertion(check).to.be.true;
});
/* jshint +W030 */

// TODO: (node) warning: possible EventEmitter memory leak detected.
process.setMaxListeners(20);

chai.use(require('sinon-chai'));
chai.use(require('chai-http'));
chai.request.addPromises(Bluebird);
chai.config.includeStack = true;

global.expect = chai.expect;
global.AssertionError = chai.AssertionError;
global.Assertion = chai.Assertion;
global.assert = chai.assert;
global.request = chai.request;
global.mockery = mockery;

mockery.registerSubstitute('../../config', '../../test/fixtures/config');
mockery.registerSubstitute('../config', '../test/fixtures/config');
mockery.registerSubstitute('./support', '../test/mocks/support');

function syncDatabase() {
  var models = require('../models');

  return models.sequelize.sync({
    force: true,
    paranoid: true
  }).then(function () {
    return models.products.bulkCreate([
      { title: 'Aliquam rutrum molestie rutrum.' },
      { title: 'Nulla laoreet.' }
    ]);
  }).then(function () {
    return models.users.bulkCreate([
      { name: 'John Brown', email: 'j.brown@gmail.com' },
      { name: 'Mark Down', email: 'mark.down@yahoo.com' }
    ]);
  });
}

//mockery.enable({
//  warnOnUnregistered: false
//});
//syncDatabase().then(function(){
//    console.log('Database synchronized');
//    mockery.disable();
//  })
//  .catch(console.error)
//  .finally(mockery.disable);

global.syncDatabase = syncDatabase;




