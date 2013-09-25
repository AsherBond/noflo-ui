Base = require './base'

class IframeRuntime extends Base
  constructor: (dataflow, graph) ->
    # Prepare the iframe and listen to its state
    @iframe = @prepareIframe dataflow.el
    @origin = window.location.origin

    super dataflow, graph

  getType: -> 'iframe'

  prepareIframe: (parent) ->
    iframe = document.createElement 'iframe'
    parent.appendChild iframe
    iframe

  connect: (preview) ->
    @iframe.addEventListener 'load', @onLoaded, false

    # Let the UI know we're connecting
    @emit 'status',
      state: 'pending'
      label: 'connecting'

    # Normalize the preview setup
    preview = @normalizePreview preview

    # Set the source to the iframe so that it can load
    @iframe.setAttribute 'src', preview.src
    @address = preview.src

    # Update iframe contents as needed
    if preview.content
      @once 'connected', =>
        body = @iframe.contentDocument.querySelector 'body'
        body.innerHTML = preview.content

    # Start listening for messages from the iframe
    window.addEventListener 'message', @onMessage, false

  normalizePreview: (preview) ->
    unless preview
      preview = {}
    unless preview.src
      preview.src = './preview/iframe.html'
    unless preview.width
      preview.width = 300
    unless preview.height
      preview.height = 300
    preview

  disconnect: (protocol) ->
    @iframe.removeEventListener 'load', @onLoaded, false

    # Stop listening to messages
    window.removeEventListener 'message', @onMessage, false
    @emit 'status',
      state: 'offline'
      label: 'disconnected'

  # Called every time the iframe has loaded successfully
  onLoaded: =>
    @emit 'status',
      state: 'online'
      label: 'connected'
    @emit 'connected'

  getElement: -> @iframe

  send: (protocol, command, payload) ->
    w = @iframe.contentWindow
    if not w or w.location.href is 'about:blank'
      return
    w.postMessage
      protocol: protocol
      command: command
      payload: payload
    , w.location.href

  onMessage: (message) =>
    switch message.data.protocol
      when 'graph' then @recvGraph message.data.command, message.data.payload
      when 'network' then @recvNetwork message.data.command, message.data.payload
      when 'component' then @recvComponent message.data.command, message.data.payload

module.exports = IframeRuntime
