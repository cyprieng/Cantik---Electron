path = require 'path'
React = require 'react'
ReactDOM = require 'react-dom'
Artwork = require '../../src/artwork'

remote = require 'remote'
Menu = remote.require 'menu'
MenuItem = remote.require 'menu-item'

formatTime = require('../../src/utils').formatTime

module.exports.LocalLibraryComponent=
class LocalLibraryComponent extends React.Component
  constructor: (props) ->
    super props

    @state = {
      showing: 'loading'
    }

    @temporaryCache = null
    @stopRendering = false

    do @renderArtistsList

    @props.localLibrary.on('library_path_change', =>
      do @renderArtistsList)

    @props.localLibrary.on('library_loading', =>
      @max = 0
      @stopRendering = true
      @setState showing: 'loading')

    @props.localLibrary.on('totreat_updated', (toTreat) =>
      @max = toTreat if toTreat > @max
      todo = @max - toTreat
      @renderProgress(todo, @max))

    @props.localLibrary.on('library_loaded', =>
      do @renderArtistsList)

    @props.localLibrary.on('go_home', =>
      do @renderArtistsList)

    @props.localLibrary.on('filter', (filter) =>
      @filterLibrary filter)

  renderMessage: (msg) ->
    <div className="msg-info">
      <h1>{msg}</h1>
    </div>

  renderLoading: ->
    <div className="sk-folding-cube loading">
      <div className="sk-cube1 sk-cube"></div>
      <div className="sk-cube2 sk-cube"></div>
      <div className="sk-cube4 sk-cube"></div>
      <div className="sk-cube3 sk-cube"></div>
    </div>

  renderProgress: (todo, max) ->
    @temporaryCache = <div className="progress">
      <div className="sk-folding-cube loading">
        <div className="sk-cube1 sk-cube"></div>
        <div className="sk-cube2 sk-cube"></div>
        <div className="sk-cube4 sk-cube"></div>
        <div className="sk-cube3 sk-cube"></div>
      </div>
      <h3 className="progress-txt">Scanning... {todo} / {max}</h3>
    </div>
    @setState showing: 'cache'

  filterLibrary: (filter) =>
    @props.localLibrary.history.addHistoryEntry(@filterLibrary.bind(@, filter))
    @setState showing: 'loading'

    @props.localLibrary.search(filter, (tracks) =>
      @temporaryCache = @buildTrackList(tracks, null, null, null, filter)
      @setState showing: 'cache')

  addTracksToPlaylist: (trackToPlay, tracks) ->
    tracksDoc = (track.doc for track in tracks)

    @props.localLibrary.pluginManager.plugins.playlist.cleanPlaylist()
    @props.localLibrary.pluginManager.plugins.playlist.addTracks(tracksDoc)
    @props.localLibrary.pluginManager.plugins.playlist.tracklistIndex = -1 + tracks.indexOf trackToPlay
    @props.localLibrary.pluginManager.plugins.player.next()

  addTrackToPlaylist: (track) ->
    track = track.doc
    @props.localLibrary.pluginManager.plugins.playlist.addTracks([track])

  popupMenu: (menu) ->
    menu.popup(remote.getCurrentWindow())

  buildTrackList: (tracks, artist, album, coverPath, searchQuery) ->
    # Add menu for each track
    tracksDOM = []
    for track in tracks
      do (track) =>
        # MENU
        menu = new Menu()
        menu.append(new MenuItem({ label: 'Add to playlist', click: =>
          @addTrackToPlaylist(track)}))

        tempTrack = <tr onDoubleClick={@addTracksToPlaylist.bind(@, track, tracks)} onContextMenu={@popupMenu.bind(@, menu)}>
          <td>{track.doc.metadata.track.no}</td>
          <td>{track.doc.metadata.title}</td>
          {<td>{track.doc.metadata.album}</td> if searchQuery?}
          {<td>{track.doc.metadata.artist[0]}</td> if searchQuery?}
          <td>{formatTime(track.doc.metadata.duration)}</td>
        </tr>

        tracksDOM.push(tempTrack)

    <div className="album">
      <div className="album-background" style={{backgroundImage: "url('#{coverPath}#{artist} - #{album}')"}}>
      </div>
      <div className="album-container">
        <div className="cover">
          <img draggable="false" src="" className="cover" />
        </div>

        <div className="album-info">
          {<h1 className="title"><b>{album}</b> - {artist}</h1> if not searchQuery?}
          {<h1 className="title">Results for <b>"{searchQuery}"</b></h1> if searchQuery?}

          <p className="description"></p>
        </div>

        <table className="table table-striped table-hover">
          <thead>
            <tr>
              <th>#</th>
              <th>Title</th>
              {<th>Album</th> if searchQuery?}
              {<th>Artist</th> if searchQuery?}
              <th>Duration</th>
            </tr>
          </thead>
          <tbody>
            {tracksDOM}
          </tbody>
        </table>
      </div>
    </div>

  renderAlbum: (artist, album) ->
    @props.localLibrary.history.addHistoryEntry(@renderAlbum.bind(@, artist, album))
    @setState showing: 'loading'

    @props.localLibrary.getAlbumTracks(artist, album, (tracks) =>
      Artwork.getAlbumImage(artist, album)
      coverPath = "file:///#{@props.localLibrary.userData}/images/albums/".replace(/\\/g, '/')
      @temporaryCache = @buildTrackList(tracks, artist, album, coverPath)
      @setState showing: 'cache')

  renderAlbumsList: (artist) ->
    @props.localLibrary.history.addHistoryEntry(@renderAlbumsList.bind(@, artist))
    @setState showing: 'loading'

    @props.localLibrary.getAlbums(artist, (albums) =>
      Artwork.getAlbumImage(artist, album) for album in albums
      coverPath = "file:///#{@props.localLibrary.userData}/images/albums/".replace(/\\/g, '/')
      @temporaryCache = <div>
        {<div className="figure" onClick={@renderAlbum.bind(@, artist, album)}>
          <div className="fallback-album"><div className="image" style={{backgroundImage: "url('#{coverPath}#{artist} - #{album}')"}}></div></div>
          <div className="caption">{album}</div>
        </div> for album in albums}
      </div>
      @setState showing: 'cache')

  renderArtistsList: ->
    @props.localLibrary.history.addHistoryEntry(@renderArtistsList.bind(@))
    @setState showing: 'loading'

    @props.localLibrary.getArtists((artists) =>
      if not @stopRendering
        if artists.length is 0 and @props.localLibrary.localLibrary is ''
          @setState {showing: 'msg', msg: 'You need to set your music library path in settings'}
        else if artists.length is 0
          @setState {showing: 'msg', msg: 'Empty library'}
        else
          Artwork.getArtistImage(artist) for artist in artists
          coverPath = "file:///#{@props.localLibrary.userData}/images/artists/".replace(/\\/g, '/')
          @temporaryCache = <div>
            {<div className="figure" onClick={@renderAlbumsList.bind(@, artist)}>
              <div className="fallback-artist">
                <div className="image" style={{backgroundImage: "url('#{coverPath}#{artist}')"}}>
                </div>
              </div>
              <div className="caption">{artist}</div>
            </div> for artist in artists}
          </div>
          @setState showing: 'cache'
      else
        @stopRendering = false)

  render: ->
    if @state.showing is 'loading'
      <div className="local-library">
        {do @renderLoading}
      </div>
    else if @state.showing is 'msg'
      <div className="local-library">
        {@renderMessage @state.msg}
      </div>
    else if @state.showing is "cache"
      <div className="local-library">
        {@temporaryCache}
      </div>

module.exports.show = (localLibrary, element) ->
  ReactDOM.render(
    <LocalLibraryComponent localLibrary=localLibrary />,
    element
  )
