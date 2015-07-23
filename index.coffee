'use strict';
util           = require 'util'
url            = require 'url'
_              = require 'lodash'
tinycolor      = require 'tinycolor2'
HueUtil        = require 'hue-util'
{EventEmitter} = require 'events'
debug          = require('debug')('meshblu-hue')

MESSAGE_SCHEMA =
  type: 'object'
  properties:
    lightNumber:
      type: 'number',
      required: true
    useGroup:
      type: 'boolean',
      required: true,
      default: false
    on:
      type: 'boolean',
      required: true
    color:
      type: 'string',
      required: true
    transitiontime:
      type: 'number'
    alert:
      type: 'string'
    effect:
      type: 'string'

OPTIONS_SCHEMA =
  type: 'object'
  properties:
    ipAddress:
      type: 'string',
      required: true
    apiUsername:
      type: 'string',
      required: true,
      default: 'octoblu'

class Plugin extends EventEmitter
  constructor: ->
    debug 'starting plugin'
    @options = {}
    @messageSchema = MESSAGE_SCHEMA
    @optionsSchema = OPTIONS_SCHEMA

  onMessage: (message) =>
    debug 'on message', message
    payload = message.payload
    @updateHue payload

  onConfig: (device={}) =>
    debug 'on config', username: device.username
    @username = device.username
    @setOptions device.options

  setOptions: (options={}) =>
    debug 'setOptions', options
    @options = _.extend apiUsername: 'octoblu', options
    @hue = new HueUtil @options.apiUsername, @options.ipAddress, @username, @onUsernameChange

  onUsernameChange: (username) =>
    debug 'onUsernameChange', username
    @username = username
    @emit 'update', username: @username

  updateHue: (payload={}) =>
    debug 'updating hue', payload
    @hue.changeLights payload, (error, response) =>
      return @emit 'message', devices: ['*'], topic: 'error', payload: error: error if error?
      @emit 'message', devices: ['*'], payload: response: response

module.exports =
  messageSchema: MESSAGE_SCHEMA
  optionsSchema: OPTIONS_SCHEMA
  Plugin: Plugin
