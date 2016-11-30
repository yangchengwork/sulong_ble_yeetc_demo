/*
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements.  See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership.  The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License.  You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied.  See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */

let SULONG_SERVICE_UUID = "cc747268-008d-48c1-9541-e428c310b400";
let SULONG_WRITE_UUID = "cc747268-008d-48c1-9541-e428c310b401";
let SULONG_NOTIFY_UUID = "cc747268-008d-48c1-9541-e428c310b402";

var app = {
    step: 0,
    count: 0,
    deviceid: 0,
    time: null,
    // Application Constructor
    initialize: function() {
        document.addEventListener('deviceready', this.onDeviceReady.bind(this), false);
    },

    // deviceready Event Handler
    //
    // Bind any cordova events here. Common events are:
    // 'pause', 'resume', etc.
    onDeviceReady: function() {
        this.receivedEvent('deviceready');
    },

    buttonHandle: function() {
        var message = "info";
        switch (app.step) {
            case 0:
            message = "scan";
            ble.scan([SULONG_SERVICE_UUID], 5, app.onScan, app.onScanFail);
            break;
            case 1:
            app.time = setInterval(app.onTimer, 1000);
            break;
        }
        $('#info').text(message);
    },

    onTimer: function() {
        app.sendCmd(0x31);
    },

    sendCmd: function(cmd) {
        var data = new Uint8Array(4);
        data[0] = 0x74;
        data[1] = 0x70;
        data[2] = 0x3D;
        data[3] = cmd;
        ble.write(app.deviceid, SULONG_SERVICE_UUID, SULONG_WRITE_UUID, data.buffer, function() {
            console.log("write success");
        }, app.onError);
    },

    onScan: function(device) {
        console.log("scan device " + JSON.stringify(device));
        app.deviceid = device.id;
        ble.stopScan(app.onStopScan, app.onError);
        app.connect(device);
    },

    connect: function(device) {
        var onConnect = function() {
            ble.startNotification(app.deviceid, SULONG_SERVICE_UUID, SULONG_NOTIFY_UUID, app.onData, app.onError);
            $('#btn').text("start");
            app.step = 1;
        };
        ble.connect(app.deviceid, onConnect, app.onError);
    },

    onData: function(buffer) {
        var data = new Uint8Array(buffer);
        var len = data.length;
        if ((data[len-2] == 0x0d) && (data[len-1] == 0x0a)) {
            if (data[3] == 0x31) {
                app.sendCmd(0x34);
            }
        }
    },

    onStopScan: function() {
        console.log("stop scan device");
    },

    onScanFail: function(reason) {
        app.onDataInit();
        app.onError(reason);
    },

    onDataInit: function() {
        app.step = 0;
        app.count = 0;
    },

    onError: function(reason) {
        console.log("ERROR: " + JSON.stringify(reason));
    },

    // Update DOM on a Received Event
    receivedEvent: function(id) {
        console.log('Received Event: ' + id);
        app.onDataInit();
        $('#btn').on('click', function () {
            app.buttonHandle();
        });
    }
};

app.initialize();