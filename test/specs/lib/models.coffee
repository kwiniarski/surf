'use strict'

server = null
models = null

describe 'Models provider', ->

  before ->

    @timeout 5000

    mockery.enable
      warnOnUnregistered: false
      useCleanCache: true

    server = require '../../../index'
    models = server.models

    syncDatabase().then -> server.start()

  after ->
    mockery.disable()
    server.stop();

  it 'should return defined models', ->
    expect(models).to.have.property 'products'
    expect(models).to.have.property 'users'

  it 'should return formated output from find(All) methods', (done) ->
    models.users.findById(1)
    .then (res) ->
      expect(res).to.have.property 'name', 'John Brown'
      expect(res).to.have.property 'email', 'j.brown@gmail.com'
      return res
    .then (res) ->
      expect(res).to.have.property 'id', 1
      expect(res).to.have.property 'avatar', null
      done()
