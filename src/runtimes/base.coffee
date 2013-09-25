EventEmitter = require 'emitter'

class BaseRuntime extends EventEmitter
  constructor: (@dataflow, @graph) ->
    @components = {}
    @types = {}
    @instances = {}
    @prepareComponents()
    @address = null

  getType: -> ''
  getAddress: -> @address

  # Connect to the target runtime environment (iframe URL, WebSocket address)
  connect: (target) ->

  disconnect: ->

  # Start a NoFlo Network
  start: ->
    @sendNetwork 'start'

  # Stop a NoFlo network
  stop: ->
    @sendNetwork 'stop'

  # Get a DOM element rendered by the runtime for preview purposes
  getElement: ->

  libraryUpdater: _.debounce ->
    @dataflow.plugins.library.update
      exclude: @excludeUnavailable()
  , 100

  excludeUnavailable: ->
    exclude = []
    for name, component of @dataflow.nodes
      exclude.push name unless @components[name]
    exclude

  getComponentInstance: (name, attributes) ->
    return null unless @types[name]
    type = @types[name]
    instance = new type.Model attributes
    @instances[name] = [] unless @instances[name]
    @instances[name].push instance
    instance

  loadComponents: (baseDir) ->
    @sendComponent 'list', baseDir

  prepareComponents: ->
    components = {}
    @graph.nodes.forEach (node) =>
      components[node.component] =
        name: node.component
        description: ''
        inPorts: []
        outPorts: []
      @graph.edges.forEach (edge) ->
        if edge.from.node is node.id
          components[node.component].outPorts.push
            id: edge.from.port
            type: 'all'
        if edge.to.node is node.id
          components[node.component].inPorts.push
            id: edge.to.port
            type: 'all'
      @graph.initializers.forEach (iip) ->
        if iip.to.node is node.id
          components[node.component].inPorts.push
            id: iip.to.port
            type: 'all'
    @registerComponent component for name, component of components

  registerComponent: (definition) ->
    @components[definition.name] = definition

    unless @types[definition.name]
      # Register as new component to Dataflow
      BaseType = @dataflow.node 'base'
      @types[definition.name] = @dataflow.node definition.name
      @types[definition.name].Model = BaseType.Model.extend
        defaults: ->
          defaults = BaseType.Model::defaults.call this
          defaults.type = definition.name
          defaults
        inputs: definition.inPorts
        outputs: definition.outPorts
      if definition.description
        @types[definition.name].description = definition.description

      # Update Dataflow library with this component
      do @libraryUpdater

    else
      # Update the definition
      type = @types[definition.name].Model
      type::inputs = definition.inPorts
      type::outputs = definition.outPorts
      # Update instances we already have
      if @instances[definition.name]
        @instances[definition.name].forEach @updateInstancePorts
      # Update the description
      if definition.description
        @types[definition.name].description = definition.description

  updateInstancePorts: (instance) =>
    for port in @components[instance.type].inPorts
      instancePort = instance.inputs.get port.id
      if instancePort
        instancePort.set port
      else
        instance.inputs.add
          label: port.id
          parentNode: instance
          id: port.id
          type: port.type
    for port in @components[instance.type].outPorts
      instancePort = instance.outputs.get port.id
      if instancePort
        instancePort.set port
      else
        instance.outputs.add
          label: port.id
          parentNode: instance
          id: port.id
          type: port.type

  recvComponent: (command, payload) ->
    switch command
      when 'component' then @registerComponent payload

  recvGraph: (command, payload) ->
    @emit 'graph',
      command: command
      payload: payload

  recvNetwork: (command, payload) ->
    switch command
      when 'started'
        @emit 'status',
          state: 'online'
          label: 'running'
      when 'stopped'
        @emit 'status',
          state: 'online'
          label: 'stopped'
      else
        @emit 'network',
          command: command
          payload: payload

  sendGraph: (command, payload) ->
    @send 'graph', command, payload
  sendNetwork: (command, payload) ->
    @send 'network', command, payload
  sendComponent: (command, payload) ->
    @send 'component', command, payload

module.exports = BaseRuntime
