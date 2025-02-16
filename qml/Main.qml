/*
 * Copyright (C) 2022  walking-octopus
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 3.
 *
 * cathode-tube is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */


import QtQuick 2.12
import Ubuntu.Components 1.3
import QtWebSockets 1.1
import "./Pages"
import "./Components"

MainView {
    id: root
    objectName: "mainView"
    applicationName: "cathode-tube.walking-octopus"
    automaticOrientation: true
    anchorToKeyboard: true

    width: units.gu(120)
    height: units.gu(75)

    Item {
        id: playingVideo

        property string video_id
        property string video_title
        property string channel_name
        property string thumbnail_url
        property string quality
    }

    MiniPlayer {
        id: miniPlayer

        video_id: playingVideo.video_id
        video_title: playingVideo.video_title
        channel_name: playingVideo.channel_name
        thumbnail_url: playingVideo.thumbnail_url

        onShowDetails: bottomEdge.commit()
    }

    BottomEdge {
        id: bottomEdge
        anchors {
            left: parent.left
            right: parent.right
        }

        hint.status: "Hidden" // FIXME: The hint stops being hidden after closing it
        preloadContent: true // FIXME: Do not preload the VideoDetails

        contentComponent: VideoDetails {
            id: videoPage

            main_ws_ready: websocket.active
            video_id: playingVideo.video_id
            video_title: playingVideo.video_title
            channel_name: playingVideo.channel_name
            thumbnail_url: playingVideo.thumbnail_url
            quality: playingVideo.quality
        }
    }

    PreplayDialog {
        id: preplayDialog
    }

    AdaptivePageLayout {
        id: pStack
        anchors.fill: parent
        
        function push(page, properties) {
            return pStack.addPageToNextColumn(primaryPage, page, properties);
        }
        
        layouts: PageColumnsLayout {
            when: width > units.gu(87.5);
            PageColumn {
                id: sidebar
                minimumWidth: preferredWidth;
                maximumWidth: preferredWidth;
                preferredWidth: units.gu(20) + width/7.5;

                // TODO: Hide the sidebar on the login page or video player.
                // You can set preferredWidth to 0 to hide the sidebar, but it might be a hack.
            }
            PageColumn {fillWidth: true;}
        }

        primaryPage: SidebarPage {
            isEnabled: false
            menuActions: [
                Action {
                    iconName: "go-home"
                    text: i18n.tr("Home")
                    onTriggered: pStack.push(Qt.resolvedUrl("./Pages/HomePage.qml"))
                },
                Action {
                    iconName: "history"
                    text: i18n.tr("History")
                    onTriggered: pStack.push(Qt.resolvedUrl("./Pages/History.qml"))
                },
                // TODO: Playlist menu can't be added until upstream does it
                Action {
                    iconName: "voicemail"
                    text: i18n.tr("Watch later")
                    onTriggered: pStack.push(
                        Qt.resolvedUrl("./Pages/Playlist.qml"),
                        {
                            playlist_id: "WL"
                        }
                    )
                },
                Action {
                    iconName: "thumb-up"
                    text: i18n.tr("Liked videos")
                    onTriggered: pStack.push(
                        Qt.resolvedUrl("./Pages/Playlist.qml"),
                        {
                            playlist_id: "LL"
                        }
                    )
                }
                // TODO: Add the notification tab
            ]
        }
        Component.onCompleted: pStack.push(Qt.resolvedUrl("./Pages/SplashScreen.qml"))
    }

    WebSocket {
        id: websocket
        url: "ws://localhost:8999"
        active: serverReady

        onStatusChanged: function(status) {
            switch (status) {
                case WebSocket.Connecting: {
                    print("Connecting...");
                    break;
                }
                case WebSocket.Open: {
                    print("Open");
                    break;
                }
                case WebSocket.Closing: {
                    print("Closed");
                    break;
                }
                case WebSocket.Error: {
                    print("Error");
                    break;
                }
            }
        }

        onTextMessageReceived: function(message) {
            let json = JSON.parse(message);

            switch (json.topic) {
                case "authorizationPendingEvent": {
                    print(`Please go to ${json.payload.url} and enter ${json.payload.code} to sign in.`);

                    pStack.push(
                        Qt.resolvedUrl("./Pages/LoginPage.qml"),
                        {
                            verification_url: json.payload.url,
                            code: json.payload.code,
                        },
                    );
                    break;
                }

                case "loginEvent": {
                    pStack.primaryPage.isEnabled = true;
                    pStack.push(Qt.resolvedUrl("./Pages/HomePage.qml"));
                    break;
                }
            }
        }
    }
}
