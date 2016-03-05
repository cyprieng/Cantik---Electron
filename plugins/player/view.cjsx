React = require('react')
ReactDOM = require('react-dom')
normalizeString = require('../../src/utils').normalizeString
formatTime = require('../../src/utils').formatTime

module.exports.PlayerComponent=
class PlayerComponent extends React.Component
  constructor: (props) ->
    super props
    @state = {
      'playing': @props.player.playing,
      'playingTrack': @props.player.playingTrack,
      'currentTime': null,
      'duration': null,
      'mute': false,
      'repeat': @props.player.pluginManager.plugins.playlist.repeat,
      'random': @props.player.pluginManager.plugins.playlist.random
    }

    @props.player.on('track_changed', @updatePlayingTrack.bind(@))
    @props.player.on('play_state_changed', @updatePlayingState.bind(@))
    @props.player.pluginManager.plugins.playlist.on('random_change', @updateRandom.bind(@))
    @props.player.pluginManager.plugins.playlist.on('repeat_change', @updateRepeat.bind(@))

  updatePlayingTrack: ->
    f = ->
      @refs.audioObject.load()
      do @updatePlayingState
    @setState(playingTrack: @props.player.playingTrack, f)

  updatePlayingState: ->
    @setState playing: @props.player.playing

    if @props.player.playing
      @refs.audioObject.play()
    else
      @refs.audioObject.pause()

  updateRandom: ->
    @setState random: @props.player.pluginManager.plugins.playlist.random

  updateRepeat: ->
    @setState repeat: @props.player.pluginManager.plugins.playlist.repeat

  setRandom: (random) ->
    @props.player.pluginManager.plugins.playlist.setRandom random

  switchRepeatState: ->
    do @props.player.pluginManager.plugins.playlist.switchRepeatState

  updateDuration: ->
    @setState duration: formatTime @refs.audioObject.duration

    @refs.progressBar.noUiSlider.updateOptions({
      range: {
        min: 0,
        max: @refs.audioObject.duration
      }
    })

  updateCurrentTime: ->
    @setState currentTime: formatTime @refs.audioObject.currentTime

    @refs.progressBar.noUiSlider.set(@refs.audioObject.currentTime)

  setCurrentTime: (time) ->
    @refs.audioObject.currentTime = time

  endOfTrack: ->
    if @props.player.pluginManager.plugins.playlist.repeat is "one"
      @setCurrentTime 0
      @props.player.playing = true
      do @updatePlayingState
    else
      do @props.player.next

  setMute: (mute) ->
    @setState mute: mute
    @refs.audioObject.muted = mute

  setVolume: (volume) ->
    @refs.audioObject.volume = volume

  componentDidMount: ->
    @refs.audioObject.addEventListener('durationchange', @updateDuration.bind(@))
    @refs.audioObject.addEventListener('timeupdate', @updateCurrentTime.bind(@))
    @refs.audioObject.addEventListener('ended', @endOfTrack.bind(@))
    @refs.audioObject.volume = 0.5

    noUiSlider.create(@refs.progressBar, {
      start: 0,
      connect: "lower",
      range: {
        min: 0,
        max: 100
      }
    })

    @refs.progressBar.noUiSlider.on('slide', @setCurrentTime.bind(@))

    noUiSlider.create(@refs.volumeBar, {
      start: 0.5,
      connect: "lower",
      range: {
        min: 0,
        max: 1
      }
    })

    @refs.volumeBar.noUiSlider.on('slide', @setVolume.bind(@))

  render: ->
    <div className="panel panel-default" id="player">
      <audio controls ref="audioObject" >
        {<source src={@state.playingTrack.path} /> if @state.playingTrack.path?}
      </audio>

      <p className="track-artist">
        <span className="title">{@state.playingTrack.metadata?.title}</span>
         -
        <span className="artist">{@state.playingTrack.metadata?.artist?[0]}</span>
      </p>
      <div className="panel-body">
        <div className="left-button">
          <button onClick={@props.player.back.bind(@props.player)}><i className="material-icons previous">skip_previous</i></button>
          {<button onClick={@props.player.play.bind(@props.player)}><i className="material-icons play">play_arrow</i></button> if not @state.playing}
          {<button onClick={@props.player.play.bind(@props.player)}><i className="material-icons play">pause</i></button> if @state.playing}
          <button onClick={@props.player.next.bind(@props.player)}><i className="material-icons next">skip_next</i></button>
        </div>

        <span className="elapsed-time">{@state.currentTime}</span>

        <div className="progress">
          <div ref="progressBar" className="slider shor progressbar"></div>
        </div>

        <span className="total-time">{@state.duration}</span>

        <div className="volume-container">
          {<button onClick={@setMute.bind(@, true)} className="volume-button"><i className="material-icons volume-icon">volume_up</i></button> if not @state.mute}
          {<button onClick={@setMute.bind(@, false)} className="volume-button"><i className="material-icons volume-icon">volume_mute</i></button> if @state.mute}

          <div ref="volumeBar" className="slider shor volume"></div>
        </div>

        <div className="right-button">
          {<button onClick={@switchRepeatState.bind(@)} className="repeat"><i className="material-icons">repeat</i></button> if @state.repeat is null}
          {<button onClick={@switchRepeatState.bind(@)} className="repeat active"><i className="material-icons">repeat</i></button> if @state.repeat is 'all'}
          {<button onClick={@switchRepeatState.bind(@)} className="repeat active"><i className="material-icons">repeat_one</i></button> if @state.repeat is 'one'}

          {<button onClick={@setRandom.bind(@, false)} className="random active"><i className="material-icons">shuffle</i></button> if @state.random}
          {<button onClick={@setRandom.bind(@, true)} className="random"><i className="material-icons">shuffle</i></button> if not @state.random}
        </div>
      </div>
    </div>

module.exports.show = (player, element) ->
  ReactDOM.render(
    <PlayerComponent player=player />,
    element
  )
