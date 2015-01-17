'use strict'

policies = null

asAdmin = require '../../example/api/policies/as-admin'
asUser = require '../../example/api/policies/as-user'
isAuthenticated = require '../../example/api/policies/is-authenticated'
isTrusted = require '../../example/api/policies/is-trusted'

describe 'Policies provider', ->

  beforeEach ->
    mockery.enable
      warnOnUnregistered: false
      useCleanCache: true

    policies = require '../../../lib/policies'

  afterEach mockery.disable

  describe 'module object', ->
    it 'should provide list of polices for all known controllers and their actions', ->
      expect(policies).to.have.keys ['products', 'users']

  describe 'Policy object', ->
    it 'should provide list of configured policies', ->
      expect(policies.products).to.have.keys ['create']

  describe 'top level wildcard configuration (*)', ->
    it 'should be used for all actions in all controllers unless overwritten by controller level policies', ->
      expect(policies.users._all).to.have.memberFunctions [isAuthenticated, asAdmin]
      expect(policies.products._all).to.have.memberFunctions [isTrusted]
      expect(policies.products.create).to.have.memberFunctions [isAuthenticated, asUser]

  describe 'action policies getter', ->
    it 'should return policies for controller\'s action if it was configured', ->
      expect(policies.products.get 'create').to.have.memberFunctions [isAuthenticated, asUser]
    it 'should return policies for all actions (*) if it was not configured', ->
      expect(policies.products.get 'find').to.have.memberFunctions [isTrusted]