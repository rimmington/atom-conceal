{CompositeDisposable} = require 'atom'
throttle = require 'lodash.throttle'

class Concealer
  constructor: ->
    @subscriptions = new CompositeDisposable

    @subToConfig 'replacements'
    @subToConfig 'grammars'

    @subscriptions.add atom.workspace.onDidStopChangingActivePaneItem (paneItem) =>
      @updateEditor paneItem

    @subscriptions.add atom.workspace.observeTextEditors (editor) =>
      doUpdate = throttle (=> @updateEditor editor), 100, trailing: true
      @subscriptions.add (atom.views.getView editor)?.onDidChangeScrollTop doUpdate
      @subscriptions.add editor.onDidStopChanging doUpdate
      @subscriptions.add editor.onDidChangeGrammar =>
        # If we're too fast the changes get overridden
        window.setTimeout doUpdate, 100

  dispose: ->
    @subscriptions.dispose()

  updateEditor: (editor) ->
    view = atom.views.getView editor
    return unless view

    return unless (not @grammars.length) or editor.getGrammar?().name in @grammars

    for element in view.querySelectorAll '.line span:not(.concealed)'
      replacement = @replacements[element.textContent]
      continue unless replacement

      element.classList.add 'concealed'
      element.dataset.replacement = replacement
      unless atom.config.get 'conceal.preserveWidth'
        element.dataset.replacementLength = replacement.length

  subToConfig: (name) ->
    @[name] = atom.config.get "conceal.#{name}"
    @subscriptions.add atom.config.observe "conceal.#{name}", (newValue) =>
      @[name] = newValue

module.exports =
  config:
    replacements:
      type: 'object'
      default: {}
    grammars:
      type: 'array'
      default: []
      items:
        type: 'string'
    preserveWidth:
      type: 'boolean'
      default: yes
      title: 'Preserve the width of the concealed element'
      description: 'When replacing an element you have the choice of replacing
                    the entire value (including it\'s space) or preseve the
                    width of the original element.'

  currentConcealer: null

  activate: ->
    @currentConcealer = new Concealer()

  deactivate: ->
    @currentConcealer.dispose()
    @currentConcealer = null
