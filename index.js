'use strict';
var util = require('util');
var EventEmitter = require('events').EventEmitter;
var tinycolor = require('tinycolor2');
var request = require('request');
var _ = require('lodash');
var debug = require('debug')('meshblu-hue');

var HUE_SAT_MODIFIER = 254;
var HUE_DEGREE_MODIFIER = 182.04;

var MESSAGE_SCHEMA = {
  type: 'object',
  properties: {
    lightNumber: {
      type: 'number',
      required: true
    },
    useGroup: {
      type: 'boolean',
      required: true,
      default: false
    },
    on: {
      type: 'boolean',
      required: true
    },
    color: {
      type: 'string',
      required: true
    },
    transitiontime: {
      type: 'number'
    },
    alert: {
      type: 'string'
    },
    effect: {
      type: 'string'
    }
  }
};

var OPTIONS_SCHEMA = {
  type: 'object',
  properties: {
    ipAddress: {
      type: 'string',
      required: true
    },
    apiUsername:{
      type: 'string',
      required: true,
      default: 'newdeveloper'
    },
    sensorPollInterval:{
      type: 'integer',
      required: true,
      default: 1000
    }
  }
};

function Plugin(){
  this.options = {};
  this.messageSchema = MESSAGE_SCHEMA;
  this.optionsSchema = OPTIONS_SCHEMA;
  return this;
}
util.inherits(Plugin, EventEmitter);


Plugin.prototype.onMessage = function(message){
  var payload = message.payload;
  this.updateHue(payload);
};

Plugin.prototype.onConfig = function(device) {
  this.setOptions(device.options||{});
}

Plugin.prototype.setOptions = function(options){
  var self = this;
  self.options = options;

  if(self.pollInterval) {
    clearInterval(self.pollInterval);
  }

  self.pollInterval = setInterval(function(){
    self.checkSensors();
  }, self.options.sensorPollInterval || 1000);
};

Plugin.prototype.updateHue = function(payload) {
  var uri, self, body, hsv, endpoint, action;
  self    = this;

  endpoint = 'lights';
  action = 'state';

  if (payload.useGroup) {
    endpoint = 'groups';
    action = 'action'
  }

  uri     = 'http://' + [self.options.ipAddress,'api',self.options.apiUsername,endpoint,payload.lightNumber,action].join('/');
  hsv     = tinycolor(payload.color).toHsv();
  body    = {
    on: payload.on,
    bri: parseInt(hsv.v * HUE_SAT_MODIFIER),
    hue: parseInt(hsv.h * HUE_DEGREE_MODIFIER),
    sat: parseInt(hsv.s * HUE_SAT_MODIFIER),
    alert: payload.alert,
    effect: payload.effect,
    transitiontime: payload.transitiontime
  }

  request({
    method: 'PUT',
    uri: uri,
    json: body
  }, function(error, response, body) {
    if (error) {
      self.emit('message', {devices: ['*'], topic: 'error', payload: {error: error}});
      return;
    }
    if (response.statusCode > 400){
      self.emit('message', {devices: ['*'], topic: 'error', payload: {errors: body}});
    }
  })
}

Plugin.prototype.checkSensors = function(){
  var self = this;
  var uri = 'http://' + [self.options.ipAddress,'api',self.options.apiUsername,'sensors'].join('/');

  request({method: 'GET', uri: uri, json: true}, function(error, response, body){
    if (_.isEqual(self.lastSensor, body)){
      return;
    }

    self.emit('message', {devices: ['*'], topic: 'sensor', payload: {sensors: body}});
    self.lastSensor = body;
  });
}

module.exports = {
  messageSchema: MESSAGE_SCHEMA,
  optionsSchema: OPTIONS_SCHEMA,
  Plugin: Plugin
};
