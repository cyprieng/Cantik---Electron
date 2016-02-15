fs = require('fs')
remote = require('remote')
app = remote.require('app')
Track = require('../../src/track')
Artwork = require('../../src/artwork')
path = require('path')

module.exports =
class LocalLibrary
  constructor: (@pluginManager) ->
    $('head').append($('<link rel="stylesheet" type="text/css" />').attr('href', __dirname + '/css/style.css'))

    # Read html file
    @indexHtml = fs.readFileSync(__dirname + '/html/index.html', 'utf8')
    @albumHtml = fs.readFileSync(__dirname + '/html/album.html', 'utf8')
    @history = @pluginManager.plugins.history

    localLibrary = @
    history = @history
    @element = @pluginManager.plugins.centralarea.addPanel('Local Library', 'Source', @indexHtml, ->
      do localLibrary.showArtistList)

    do @initDB
    do @showArtistList

    # TODO(Use settings)
    @localLibrary = '/media/omnius/Music'
    @parseLibrary @localLibrary

  showArtistList: ->
    localLibrary = @
    @history.addHistoryEntry({
      "plugin": @,
      "function": "showArtistList",
      "args": []
    })
    @getArtists (artists) ->
      localLibrary.element.html(localLibrary.indexHtml)
      for artist in artists.sort()
        Artwork.getArtistImage(artist)
        coverPath = "#{app.getPath('userData')}/images/artists/#{artist}"
        coverPath = coverPath.replace('"', '\\"').replace("'", "\\'")
        localLibrary.element.append("""<div class="figure">
          <div class="image" style="background-image: url('#{coverPath}');"></div>
          <div class="caption">#{artist}</div>
        </div>
        """)
      localLibrary.element.find('div.figure').click(->
        localLibrary.showAlbumsList($(this).find('.caption').text()))

  getArtists: (callback) ->
    if not @artists
      localLibrary = @
      @db.query('artistcount/artist', {reduce: true, group: true}, (err, results) ->
        localLibrary.artists = (a.key for a in results.rows)
        callback localLibrary.artists)
    else
      callback @artists

  showAlbumsList: (artist) ->
    localLibrary = @
    @history.addHistoryEntry({
      "plugin": @,
      "function": "showAlbumsList",
      "args": [artist]
    })
    @getAlbums(artist, (albums) ->
      localLibrary.element.html(localLibrary.indexHtml)
      for album in albums.sort()
        Artwork.getAlbumImage(artist, album)
        coverPath = "#{app.getPath('userData')}/images/albums/#{artist} - #{album}"
        coverPath = coverPath.replace('"', '\\"').replace("'", "\\'")
        localLibrary.element.append("""<div class="figure">
          <div class="image" style="background-image: url('#{coverPath}');"></div>
          <div class="caption">#{album}</div>
        </div>
        """)
      localLibrary.element.find('div.figure').click(->
        localLibrary.showAlbumTracksList(artist, $(this).find('.caption').text())))

  getAlbums: (artist, callback) ->
    @db.query('artist/artist', {key: artist, include_docs: true}).then((result) ->
      albums = []
      for row in result.rows
        if row.doc.metadata?.album?
          albums.push(row.doc.metadata.album) if row.doc.metadata.album not in albums
      callback albums)

  showAlbumTracksList: (artist, album) ->
    element = @element
    html = @albumHtml
    @history.addHistoryEntry({
      "plugin": @,
      "function": "showAlbumTracksList",
      "args": [artist, album]
    })
    @getAlbumTracks(artist, album, (tracks) ->
      Artwork.getAlbumImage(artist, album)
      element.html(html)
      element.find('img.cover').attr("src", "#{app.getPath('userData')}/images/albums/#{artist} - #{album}")
      element.find('.title').html("<b>#{album}</b> - #{artist}")
      for track in tracks
        element.find('tbody').append("""
        <tr>
          <td>#{track.doc.metadata.track.no}</td>
          <td>#{track.doc.metadata.title}</td>
          <td>#{track.doc.metadata.duration}</td>
        </tr>
        """))

  getAlbumTracks: (artist, album, callback) ->
    @db.query('album/album', {key: album, include_docs: true}).then((result) ->
      tracks = []
      for row in result.rows
        tracks.push(row) if row.doc.metadata?.artist? and row.doc.metadata.artist[0] is artist
      callback tracks)

  initDB: ->
    @db = new PouchDB('library')
    @db.put({
      _id: '_design/artist',
      views: {
        'artist': {
          map: 'function (doc) { emit(doc.metadata.artist[0]); }'
        }
      }
    })
    @db.put({
      _id: '_design/artistcount',
      views: {
        'artist': {
          map: 'function (doc) { emit(doc.metadata.artist[0]); }',
          reduce: '_count'
        }
      }
    })
    @db.put({
      _id: '_design/album',
      views: {
        'album': {
          map: 'function (doc) { emit(doc.metadata.album); }'
        }
      }
    })

  parseLibrary: (libraryPath) ->
    db = @db
    files = fs.readdirSync(libraryPath)

    # Get the files
    for file in files
      if file[0] != '.'
          filePath = "#{libraryPath}/#{file}"
          stat = fs.statSync(filePath)

          if stat.isDirectory()
            @parseLibrary filePath
          else if path.extname(filePath) in ['.ogg', '.flac', '.aac', '.mp3', '.m4a']
            # Check already ingested
            db.get(filePath, (err, data) ->
              if not err and not data
                new Track(filePath, (t) ->
                  t._id = t.path
                  db.put(t)
                  ))