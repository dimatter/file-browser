FileBrowserView = require './file-browser-view'
{CompositeDisposable} = require 'atom'
fs = require 'fs'
path = require 'path'

getDirectoryfiles = (directory)->
  @files = fs.readdirSync(directory)
  folderList = [
    showedFilename: '..'
    realFilename: path.dirname(directory)
    isDir: true
  ]
  fileList = []
  for fileName in @files
    filePath = path.join(directory, fileName)
    item =
      showedFilename: fileName
      realFilename: filePath
      isDir: fs.lstatSync(filePath).isDirectory()
    if item.isDir then folderList.push item else fileList.push item

  folderList.concat fileList

module.exports = FileBrowser =
  currentDirectory: null
  fileBrowserView: null
  subscriptions: null
  panel: null

  activate: (state) ->
    @currentDirectory = state.currentDirectory
    @fileBrowserView = new FileBrowserView()

    @subscriptions = new CompositeDisposable
    @subscriptions.add atom.commands.add 'atom-workspace', 'file-browser:open': => @open()
    @subscriptions.add atom.commands.add 'atom-workspace', 'file-browser:search': => @search()

  deactivate: ->
    @subscriptions.dispose()
    @fileBrowserView.destroy()

  serialize: ->
    currentDirectory: @currentDirectory

  open: ->
    editor = atom.workspace.getActiveTextEditor()
    filePath = atom.project.rootDirectories[0].path + '/.'
    if editor
      filePath = editor.getPath()

    @currentDirectory = path.dirname(filePath)
    @files = getDirectoryfiles(@currentDirectory)

    @fileBrowserView = new FileBrowserView()
    @fileBrowserView.setFiles(@files)
    pane = atom.workspace.getActivePane()
    filebrowserEditor = pane.addItem(@fileBrowserView)
    pane.activateItem(filebrowserEditor)
    filebrowserEditor.model.insertNewline = => @handleOpen filebrowserEditor

    filebrowserEditor.keydown (event) =>
      # enter
      if event.which == 13
        event.stopPropagation()
        @handleOpen filebrowserEditor
      # backspace
      if event.which == 8
        event.stopPropagation()
        previousDirectory = @currentDirectory
        @currentDirectory = path.dirname(@currentDirectory)
        @files = getDirectoryfiles(@currentDirectory)
        row = @files.map (i) ->
          i.realFilename
        .indexOf previousDirectory
        @fileBrowserView.setFiles(@files)

        cursor = filebrowserEditor.model.cursors[0]
        cursor.moveToTop()
        cursor.moveDown(row)
    return

  handleOpen: (filebrowserEditor) ->
    cursor = filebrowserEditor.model.cursors[0]
    file = @files[cursor.getBufferRow()]
    @currentDirectory = file.realFilename
    if file.isDir
      @files = getDirectoryfiles(file.realFilename)
      @fileBrowserView.setFiles(@files)
    else
      atom.workspace.open(file.realFilename)
    cursor.moveToTop()

  search: ->
    return if atom.workspace.getActiveTextEditor()
    target = atom.views.getView(atom.workspace.getActivePane().activeItem)
    target.dataset.path = @currentDirectory
    atom.commands.dispatch target, 'project-find:show-in-current-directory'
