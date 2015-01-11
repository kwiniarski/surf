'use strict';
RequestError = require('../../lib/errors').RequestError
lodash = require 'lodash'
configFixture = require '../fixtures/config'
support = require '../../lib/support'
supportStub = null
sinon = require 'sinon'
express = require 'express'
app = express()
app.use require '../../middleware/request'
app.use require '../../middleware/response'
app.use require('body-parser').json()
server = null
agent = request app

Sequelize = require 'sequelize'

sequelize = new Sequelize 'test_surf', process.env.USER, '',
  dialect: 'mysql'
  logging: false

Resources = sequelize.define 'resources',
  title: Sequelize.STRING

Users = sequelize.define 'users',
  name: Sequelize.STRING
  email:
    type: Sequelize.STRING
    validate:
      isEmail: true
  avatar:
    type: Sequelize.STRING
    allowNull: true

UsersController =
  listAvatarImages: (req, res) ->
    Users.findAll { attributes: ['avatar'] }
    .then res.ok
  addAvatarImage: (req, res) ->
    Users.update { avatar: req.body.image }, { where: id: req.param 'id' }
    .then ->
      Users.find req.param 'id'
    .then res.ok
  find: (req, res, next) ->
    Users.find
      where:
        email: req.params[0]
    .done (err, data) ->
      return next RequestError.BadRequest err if err
      return next RequestError.NotFound() if lodash.isEmpty(data)
      res.ok data

controllersConfigFixture =
  users:
    find:
      route: /^\/([\w\.]+@[\w\.]+)$/i
    addAvatarImage:
      methods: ['post']
      route: '/add-image'

policiesConfigFixture =
  '*': ['isMobile']
  resources:
    create: ['isAdmin', 'isAuthenticated']
  users:
    '*': ['isAdmin']

middlewareMock = (req, res, next) ->
  next();
isMobile = sinon.spy middlewareMock
isAuthenticated = sinon.spy middlewareMock
isAdmin = sinon.spy middlewareMock

describe 'Route provider', ->

  before (done) ->

    supportStub = sinon.stub support, 'listFiles'
    supportStub.withArgs(configFixture.CONTROLLERS_DIR).returns
      users: '/app/api/controllers/users'
    supportStub.withArgs(configFixture.POLICIES_DIR).returns
      isMobile: '/app/api/policies/isMobile'
      isAuthenticated: '/app/api/policies/isAuthenticated'
      isAdmin: '/app/api/policies/isAdmin'
    supportStub.throws 'STUB_ENOENT'

    sequelize.sync
      force: true
    .then ->
      Resources.bulkCreate [
        { title: 'Aliquam rutrum molestie rutrum.' }
        { title: 'Nulla laoreet.' }
      ]
    .then ->
      Users.bulkCreate [
        { name: 'John Brown', email: 'j.brown@gmail.com' }
        { name: 'Mark Down', email: 'mark.down@yahoo.com' }
      ]
    .done done

    registerMock '/app/config/controllers', controllersConfigFixture
    registerMock '/app/config/policies', policiesConfigFixture
    registerMock '/app/api/controllers/users', UsersController
    registerMock '/app/api/policies/isMobile', isMobile
    registerMock '/app/api/policies/isAuthenticated', isAuthenticated
    registerMock '/app/api/policies/isAdmin', isAdmin
    registerMock '../config', configFixture
    registerMock './support', support
    registerMock './models',
      resources: Resources
      users: Users

    mockery.enable
      warnOnUnregistered: false
      warnOnReplace: false
      useCleanCache: true

    app.use require '../../lib/routes'
    app.use require '../../middleware/errors-handler'
    server = app.listen 9000

  after (done) ->

    server.on 'close', done
    supportStub.restore()
    mockery.deregisterAll()
    mockery.disable()
    server.close()

  describe 'mount CRUD routes for the resource model', ->

    describe 'GET /resources route', ->
      it 'should return subset of all resources', (done) ->
        agent.get('/resources').end (err, res) ->
          expect(err).to.be.null
          expect(res).to.be.json.and.have.status 200
          expect(res.body).to.have.deep.property '[0].title', 'Aliquam rutrum molestie rutrum.'
          expect(res.body).to.have.deep.property '[1].title', 'Nulla laoreet.'
          done()

    describe 'GET /resources/:id route', ->
      it 'should return selected resource', (done) ->
        agent.get('/resources/2').end (err, res) ->
          expect(err).to.be.null
          expect(res).to.be.json.and.have.status 200
          expect(res.body).to.have.deep.property 'title', 'Nulla laoreet.'
          expect(res.body).to.have.deep.property 'id', 2
          done()

    describe 'POST /resources route', ->
      it 'should create exactly one record with new id', (done) ->
        agent.post('/resources').send({ title: 'Lorem ipsum dolor sit amet.' }).end (err, res) ->
          expect(err).to.be.null
          expect(res).to.have.status(201).and.have.header 'location', '/resources/3'
          expect(res.body).to.be.empty
          done()

    describe 'PUT /resources/:id route', ->
      it 'should update record with given id if it exists with new data', (done) ->
        agent.put('/resources/3').send({ title: 'Nunc id velit vel metus.' }).end (err, res) ->
          expect(err).to.be.null
          expect(res).to.have.status 204
          expect(res.body).to.be.empty
          done()
      it 'should create record under given id if it not exists', (done) ->
        agent.put('/resources/4').send({ title: 'Lorem ipsum dolor sit amet.' }).end (err, res) ->
          expect(err).to.be.null
          expect(res).to.have.status(201).and.have.header 'location', '/resources/4' # cannot test it with SQLite
          expect(res.body).to.be.empty
          done()

    describe 'DELETE /resources/:id route', ->
      it 'should delete selected record and return 204 No Content status', (done) ->
        agent.delete('/resources/4').end (err, res) ->
          expect(err).to.be.null
          expect(res).to.have.status 204
          expect(res.body).to.be.empty
          done()

  describe 'when controller is created for the resource model', ->

    describe 'extend blueprint routes overwriting CRUD methods when needed', ->
      it 'should not return any data for overwritten method because email have to be provided as id', (done) ->
        agent.get('/users/1').end (err, res) ->
          expect(err).to.be.null
          expect(res).to.be.json.and.have.status 404
          expect(res.body).to.be.not.null
          done()
      it 'should return data for overwritten method because valid email is provided as id', (done) ->
        agent.get('/users/j.brown@gmail.com').end (err, res) ->
          expect(err).to.be.null
          expect(res).to.be.json.and.have.status 200
          expect(res.body).to.have.deep.property 'name', 'John Brown'
          done()

    describe 'extend blueprints with custom methods converting controller name to URL', ->
      it 'should add GET /users/list-avatar-images from listAvatarImages method', (done) ->
        agent.get('/users/list-avatar-images').end (err, res) ->
          expect(err).to.be.null
          expect(res).to.be.json.and.have.status 200
          expect(res.body).to.have.deep.property '[0].avatar', null
          expect(res.body).to.have.deep.property '[1].avatar', null
          done()

  describe 'when controller configuration is created for the resource model', ->
    it 'should add POST /users/add-image route using addAvatarImage method and its configuration', (done) ->
      agent.post('/users/add-image').send({ image: 'avatar.png', id: 1 }).end (err, res) ->
        expect(err).to.be.null
        expect(res).to.be.json.and.have.status 200
        expect(res.body).to.have.deep.property 'avatar', 'avatar.png'
        done()

  describe 'error handling', ->
    it 'should return 400 Bad request for model validation errors', (done) ->
      agent.post('/users').send
        name: 'John Novak'
        email: 'novak.mail'
        avatar: 'novak.png'
      .end (err, res) ->
        expect(res).to.be.json.and.have.status 400
        expect(res.body).to.have.deep.property 'name', 'Bad Request'
        expect(res.body).to.have.deep.property 'message', 'Validation error'
        expect(res.body).to.have.deep.property 'errors[0].message', 'Validation isEmail failed'
        done()
    it 'should return 404 Not Found for missing routes', (done) ->
      agent.get('/users/not/existing/url').end (err, res) ->
        expect(res).to.be.json.and.have.status 404
        expect(res.body).to.have.deep.property 'name', 'Not Found'
        done()
    it 'should return 405 Method Not Allowed status for missing VERBs', (done) ->
      agent.put('/users/add-image').end (err, res) ->
        expect(res).to.be.json.and.have.status 405
        expect(res.body).to.have.deep.property 'name', 'Method Not Allowed'
        done()

