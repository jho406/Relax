ComponentUrl = require('./component_url')
Snapshot = require('./snapshot')
DoublyLinkedList = require('./doubly_linked_list')
Utils = require('./utils')
EVENTS = require('./events')
PAGE_CACHE_SIZE = 20
Config = require('./config')
ProgressBar = require('./progress_bar')
Request = require('./request_response').request

class Controller
  constructor: (history, onCrossOriginRequest = ->{})->
    @atomCache = {} #todo rename me....
    @queues = {}
    @history = new Snapshot(this, history)
    @unlisten = history.listen(@history.onHistoryChange)

    @transitionCacheEnabled = false
    @requestCachingEnabled = true
    @progressBar = new ProgressBar
    @onCrossOriginRequest = onCrossOriginRequest

  reset: ->
    @transitionCacheEnabled = false
    @atomCache = {}
    @queues = {}
    @unlisten()
    @history.reset()

  setInitialUrl: (url) =>
    @history.setInitialUrl(url)

  setInitialState: ({pathname, state }) =>
    @setInitialUrl(pathname)
    @history.setInitialUrl(pathname)
    @setCSRFToken(state.csrf_token)
    @replace(state)

  setCSRFToken: (token) =>
    @csrfToken = token

  currentPage: =>
    @history.currentPage

  fetchQueue:(name) =>
    @queues[name] ?= new (Config.fetchQueue(name))

  request: (url, options = {}) =>
    options = Utils.reverseMerge options,
      onProgress: -> {}
      onRequestStart: -> {}
      onRequestError: -> {}
      onRequestEnd: -> {}
      onProgress: -> {}
      pushState: true
      queue: 'sync'

    queue = @queue = @fetchQueue(options.queue)
    url = new ComponentUrl url, Config.fetchBaseUrl()

    if url.crossOrigin()
      @onCrossOriginRequest(url)
      return

    @history.cacheCurrentPage()
    if options.queue == 'sync'
      @progressBar.start()

    restorePoint = @history.transitionCacheFor(url.pathname)
    if @transitionCacheEnabled and restorePoint and restorePoint.transition_cache
      @history.reflectNewUrl(url)
      @restore(restorePoint)

    options.cacheRequest ?= @requestCachingEnabled
    options.onRequestStart?(url.absolute)

    queue.push(@createRequest(url, options))

  createRequest: (url, options)=>
    jsAccept = 'text/javascript, application/x-javascript, application/javascript'

    req =
      controller: @
      url: url
      header:
        'accept': jsAccept
        'x-xhr-referer': @currentPage().url
        'x-requested-with': 'XMLHttpRequest'
      payload: options.payload
      method: options.requestMethod || 'GET'
      onRequestError: options.onRequestError
      onProgress: options.onProgress
      onRequestEnd: options.onRequestEnd
      cacheRequest: options.cacheRequest
      pushState: options.pushState
      queue: options.queue

    if options.silent?
      req.header['x-silent'] =  options.silent

    if options.contentType?
      req.header['content-type'] =  options.contentType

    if @csrfToken?
      req.header['x-csrf-token'] = @csrfToken

    new Request req

  enableTransitionCache: (enable = true) =>
    @transitionCacheEnabled = enable

  disableRequestCaching: (disable = true) =>
    @requestCachingEnabled = not disable
    disable

  restore: (cachedPage, options = {}) =>
    @progressBar.done()
    @history.changePage(cachedPage, options)

    Utils.emitter.emit EVENTS.RESTORE
    Utils.emitter.emit EVENTS.LOAD, cachedPage

  replace: (nextPage, options = {}) =>
    Utils.withDefaults(nextPage, @history.currentBrowserState)
    @history.changePage(nextPage, options)
    Utils.emitter.emit EVENTS.LOAD, @currentPage()

  cache: (key, value) =>
    return @atomCache[key] if value == null
    @atomCache[key] ||= value

  clearCache: (key, value) =>
    @atomCache = {}

  onProgress: (event)=>
    @progressBar.advanceFromEvent(event)

  onLoad: (rsp) =>
    #todo: investigate: react-native might not need the following line.
    redirectedUrl = rsp.header['x-xhr-redirected-to']
    url = new ComponentUrl(redirectedUrl || rsp.url)

    if rsp.status == 204
      return

    rsp.onRequestEnd?(url.absolute)
    nextPage =  @processResponse(rsp)

    if nextPage
      if rsp.queue != 'sync' && url.pathname != @currentPage().pathname

        unless rsp.ignoreSamePathConstraint
          Utils.warn("Async response path is different from current page path")

      if rsp.pushState
        @history.reflectNewUrl url

      Utils.withDefaults(nextPage, @history.currentBrowserState)

      if nextPage.action != 'graft'
        @history.changePage(nextPage)
        Utils.emitter.emit EVENTS.LOAD, @currentPage()
      else
        #todo: clean this up
        @history.graftByKeypath("data.#{nextPage.path}", nextPage.data)

      @progressBar.done()
      @history.constrainPageCacheTo()
    else
      rsp.onRequestError(rsp)

  processResponse: (rsp) ->
    if @hasValidResponse(rsp)
      return @responseContent(rsp.body)

  hasValidResponse: (xhr) ->
    not @clientOrServerError(xhr) and @validContent(xhr) and not @downloadingFile(xhr)

  responseContent: (body) ->
    new Function("'use strict'; return " + body)()

  clientOrServerError: (xhr) ->
    400 <= xhr.status < 600

  validContent: (rsp) ->
    contentType = rsp.header['content-type']
    jsContent = /^(?:text\/javascript|application\/x-javascript|application\/javascript)(?:;|$)/

    contentType? and contentType.match jsContent

  downloadingFile: (xhr) ->
    (disposition = xhr.header['content-disposition'])? and
      disposition.match /^attachment/


module.exports = Controller