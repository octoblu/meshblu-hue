'use strict';
util           = require 'util'
url            = require 'url'
_              = require 'lodash'
tinycolor      = require 'tinycolor2'
{EventEmitter} = require 'events'
debug          = require('debug')('meshblu-hue')

HUE_SAT_MODIFIER = 254;
HUE_DEGREE_MODIFIER = 182.04;

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
    @options = {}
    @messageSchema = MESSAGE_SCHEMA
    @optionsSchema = OPTIONS_SCHEMA

  onMessage: (message) =>
    payload = message.payload;
    @updateHue payload

  onConfig: (device) =>
    @setOptions device.options

  setOptions: (options={}) =>
    @options = _.extend apiUsername: 'octoblu', options

  getUri: (path) =>
    url.format
      protocol: 'http'
      hostname: @options.ipAddress
      pathname: path

  handleResponseErrors: (error, response, body, callback=->) =>
    return callback error if error?
    return callback body if response.statusCode > 400
    if _.isArray body && body[0]?.error?
      return callback body[0].error
    callback()

  getBridgeIp: () =>
    requestOptions =
      
  checkHueBridge: (callback=->) =>
    requestOptions =
      method: 'GET'
      uri: getUri "/api/#{@options.apiUsername}"
    request requestOptions, (error, response, body) =>
      @handleResponseErrors error, response, body, callback

  createUser: (callback=->) =>
    requestOptions =
      method: 'POST'
      uri: getUri "/api"
      json: devicetype: @options.apiUsername

    request requestOptions, (error, response, body) =>
      @handleResponseErrors error, response, body, callback

  updateHue: (payload={}) =>
    endpoint = 'lights'
    action = 'state'

    endpoint = 'groups' if payload.useGroup
    action = 'action' if payload.useGroup

    uri = getUri "/api/#{@options.apiUsername}/#{endpoint}/#{payload.lightNumber}/#{action}"

    hsv = tinycolor(payload.color).toHsv()
    body =
      on: payload.on
      alert: payload.alert
      effect: payload.effect
      transitiontime: payload.transitiontime

    colorDefaults =
      bri: parseInt(hsv.v * HUE_SAT_MODIFIER)
      hue: parseInt(hsv.h * HUE_DEGREE_MODIFIER)
      sat: parseInt(hsv.s * HUE_SAT_MODIFIER)
    body = _.extend colorDefaults, body if payload.color

    requestOptions =
      method: 'PUT'
      uri: uri
      json: body

    request requestOptions, (error, response, body) =>
      @handleResponseErrors error, response, body, =>
        return @emit 'message', devices: ['*'], topic: 'error', payload: error: error if error?

module.exports =
  messageSchema: MESSAGE_SCHEMA
  optionsSchema: OPTIONS_SCHEMA
  Plugin: Plugin
