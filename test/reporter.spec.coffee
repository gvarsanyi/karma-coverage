#==============================================================================
# lib/reporters/Coverage.js module
#==============================================================================
describe 'reporter', ->
  events = require 'events'
  path = require 'path'
  istanbul = require 'istanbul'

  # TODO(vojta): remove the dependency on karma
  helper = require '../node_modules/karma/lib/helper'
  Browser = require '../node_modules/karma/lib/browser'
  Collection = require '../node_modules/karma/lib/browser_collection'
  require('../node_modules/karma/lib/logger').setup 'INFO', false, []

  nodeMocks = require 'mocks'
  loadFile = nodeMocks.loadFile
  m = null

  mockFs =
    writeFile: sinon.spy()

  mockStore = sinon.spy()
  mockStore.mix = (fn, obj) ->
    istanbul.Store.mix fn, obj
  mockFslookup = sinon.stub
    keys: ->
    get: ->
    hasKey: ->
    set: ->
  mockStore.create = sinon.stub().returns mockFslookup

  mockAdd = sinon.spy()
  mockDispose = sinon.spy()
  mockCollector = class Collector
    add: mockAdd
    dispose: mockDispose
    getFinalCoverage: -> null
  mockWriteReport = sinon.spy()
  mockReportCreate = sinon.stub().returns writeReport: mockWriteReport
  mockMkdir = sinon.spy()
  mockHelper =
    isDefined: (v) -> helper.isDefined v
    merge: (v...) -> helper.merge v...
    mkdirIfNotExists: mockMkdir
    normalizeWinPath: (path) -> helper.normalizeWinPath path

  mocks =
    fs: mockFs
    istanbul:
      Store: mockStore
      Collector: mockCollector
      Report: create: mockReportCreate
    dateformat: require 'dateformat'

  beforeEach ->
    m = loadFile __dirname + '/../lib/reporter.js', mocks

  describe 'BasePathStore', ->
    options = store = null

    beforeEach ->
      options =
        basePath: 'path/to/coverage/'
      store = new m.BasePathStore options

    describe 'toKey', ->
      it 'should concat relative path and basePath', ->
        expect(store.toKey './foo').to.deep.equal path.join(options.basePath, 'foo')

      it 'should does not concat absolute path and basePath', ->
        expect(store.toKey '/foo').to.deep.equal '/foo'

    it 'should call keys and delegate to inline store', ->
      store.keys()
      expect(mockFslookup.keys).to.have.been.called

    it 'should call get and delegate to inline store', ->
      key = './path/to/js'
      store.get(key)
      expect(mockFslookup.get).to.have.been.calledWith path.join(options.basePath, key)

    it 'should call hasKey and delegate to inline store', ->
      key = './path/to/js'
      store.hasKey(key)
      expect(mockFslookup.hasKey).to.have.been.calledWith path.join(options.basePath, key)

    it 'should call set and delegate to inline store', ->
      key = './path/to/js'
      content = 'any content'
      store.set key, content
      expect(mockFslookup.set).to.have.been.calledWith path.join(options.basePath, key), content

  describe 'CoverageReporter', ->
    rootConfig = emitter = reporter = null
    browsers = fakeChrome = fakeOpera = null
    mockLogger = create: (name) ->
      debug: -> null
      info: -> null
      warn: -> null
      error: -> null

    beforeEach ->
      rootConfig =
        basePath: '/base'
        coverageReporter: dir: 'path/to/coverage/'
      emitter = new events.EventEmitter
      reporter = new m.CoverageReporter rootConfig, mockHelper, mockLogger
      browsers = new Collection emitter
      # fake user agent only for testing
      # cf. helper.browserFullNameToShort
      fakeChrome = new Browser 'aaa', 'Windows NT 6.1 Chrome/16.0.912.75', browsers, emitter
      fakeOpera = new Browser 'bbb', 'Opera/9.80 Mac OS X Version/12.00', browsers, emitter
      browsers.add fakeChrome
      browsers.add fakeOpera
      reporter.onRunStart()
      browsers.forEach (b) -> reporter.onBrowserStart b
      mockMkdir.reset()

    it 'has no pending file writings', ->
      done = sinon.spy()
      reporter.onExit done
      expect(done).to.have.been.called

    it 'has no coverage', ->
      result =
        coverage: null
      reporter.onBrowserComplete fakeChrome, result
      expect(mockAdd).not.to.have.been.called

    it 'should handle no result', ->
      reporter.onBrowserComplete fakeChrome, undefined
      expect(mockAdd).not.to.have.been.called

    it 'should make reports', ->
      reporter.onRunComplete browsers
      expect(mockMkdir).to.have.been.calledTwice
      dir = rootConfig.coverageReporter.dir
      expect(mockMkdir.getCall(0).args[0]).to.deep.equal path.resolve('/base', dir, fakeChrome.name)
      expect(mockMkdir.getCall(1).args[0]).to.deep.equal path.resolve('/base', dir, fakeOpera.name)
      mockMkdir.getCall(0).args[1]()
      expect(mockReportCreate).to.have.been.called
      expect(mockWriteReport).to.have.been.called
