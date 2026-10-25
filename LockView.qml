import QtQuick
import QtQuick.Effects
import qs.Commons
import qs.Commons as Commons
import qs.Ui

Item {
  id: root

  property string backgroundPath: ""
  property int backgroundVersion: 0
  property bool fingerprintConfigured: false
  property bool authenticatingPassword: false
  property string failureMessage: ""
  property int failedAttempts: 0
  property bool inputEnabled: true
  property bool loadBackground: true
  property string passwordText: ""
  property bool syncingPasswordText: false

  // Neon sweep animation. `animated` gates it to the GTA VI theme; `active`
  // turns true once the surface is on screen, `unlocking` while the service
  // holds the lock for the outro after a successful authentication.
  property bool animated: false
  property bool active: false
  property bool unlocking: false
  property real backdropScale: 1
  property real blurAmount: 1
  property real fieldOffset: 0
  property real fieldScale: 1
  property real fieldOpacity: 1
  property real glowStrength: 0
  property real sweepProgress: 0
  property string cardTitle: ""
  property string cardSubtitle: ""
  property real cardScale: 1
  property real cardOpacity: 0
  readonly property color cardGold: "#ffc46b"
  property color cardColor: cardGold
  property real backdropSaturation: 0
  readonly property color neonA: Commons.Color.accent
  readonly property color neonB: "#c77dff"
  // Wanted stars shrink to fit once the password outgrows the field, like the dots.
  readonly property int starCount: starFlashing ? flashStarCount : passwordInput.text.length
  readonly property real starSize: Math.max(8, Math.min(fieldFontSize * 1.15, (passwordInput.width - 4) / Math.max(1, starCount) / 1.25))

  // A wrong password clears the field at once, so the flash replays the stars
  // it had, blinking police red and blue with a shake.
  property int lastSubmittedLength: 0
  property int flashStarCount: 0
  property bool starFlashing: false
  property real flashStep: 0
  readonly property color flashRed: "#ff4f6d"
  readonly property color flashBlue: "#6c9cff"

  function stopStarFlash() {
    flashAnim.stop()
    starFlashing = false
    flashStep = 0
    if (bustedAnim.running) {
      bustedAnim.stop()
      cardOpacity = 0
      backdropSaturation = 0
    }
  }

  // A wrong password gets the stars flashing and a BUSTED card over a
  // drained, grey wallpaper.
  onFailedAttemptsChanged: {
    if (!animated || failedAttempts === 0 || lastSubmittedLength === 0) return
    if (introAnim.running) introAnim.complete()
    flashStarCount = lastSubmittedLength
    flashAnim.restart()
    bustedAnim.restart()
  }

  ParallelAnimation {
    id: bustedAnim
    SequentialAnimation {
      PropertyAction { target: root; property: "cardTitle"; value: "BUSTED" }
      PropertyAction { target: root; property: "cardSubtitle"; value: "Wrong password" }
      PropertyAction { target: root; property: "cardColor"; value: root.flashRed }
      PropertyAction { target: root; property: "cardOpacity"; value: 0 }
      ParallelAnimation {
        NumberAnimation { target: root; property: "cardScale"; from: 2.2; to: 1; duration: 260; easing.type: Easing.OutBack }
        NumberAnimation { target: root; property: "cardOpacity"; from: 0; to: 1; duration: 160 }
      }
      PauseAnimation { duration: 1100 }
      NumberAnimation { target: root; property: "cardOpacity"; to: 0; duration: 300; easing.type: Easing.InQuad }
    }
    SequentialAnimation {
      NumberAnimation { target: root; property: "backdropSaturation"; to: -1; duration: 200; easing.type: Easing.OutQuad }
      PauseAnimation { duration: 1060 }
      NumberAnimation { target: root; property: "backdropSaturation"; to: 0; duration: 400; easing.type: Easing.InOutQuad }
    }
  }

  SequentialAnimation {
    id: flashAnim
    PropertyAction { target: root; property: "starFlashing"; value: true }
    NumberAnimation { target: root; property: "flashStep"; from: 0; to: 6; duration: 1100 }
    PropertyAction { target: root; property: "starFlashing"; value: false }
    PropertyAction { target: root; property: "flashStep"; value: 0 }
  }

  readonly property string placeholderText: "Enter Password"
  readonly property int fieldWidth: 381
  readonly property int fieldHeight: 67
  readonly property int outlineThickness: 3
  readonly property int fieldFontSize: Math.round(Style.font.heading * 1.125)
  readonly property int passwordDotFontSize: Math.round(Style.font.heading * 1.33)
  readonly property int passwordDotLetterSpacing: Math.round(Style.font.heading * 0.19)
  // Space to keep clear on each side of the field for the fingerprint icon
  // (icon width plus a gap) so the centered dots never run under it.
  readonly property real fingerprintReserve: fingerprintConfigured ? Math.round(fingerprintIcon.implicitWidth + 12) : 0
  // Shrink the dots to fit once the password outgrows the field, so every
  // keystroke stays visible — otherwise long passwords clip with no feedback.
  readonly property real passwordDotScale: dotMetrics.advanceWidth > 0
    ? Math.min(1, (passwordInput.width - 4) / dotMetrics.advanceWidth)
    : 1
  readonly property bool showPasswordCursor: inputEnabled && !authenticatingPassword && failureMessage.length === 0
  readonly property bool errorState: failureMessage.length > 0
  readonly property var inputBorderSpec: errorState
    ? Border.surfaceSpec("lock", "border-error", Commons.Color.lock.borderError, root.outlineThickness, "border-alpha")
    : Border.surfaceSpec("lock", "border-active", Commons.Color.lock.borderActive, root.outlineThickness, "border-alpha")

  signal submitPassword(string password)
  signal passwordTextEdited(string password)
  signal clearFailureRequested()
  signal wakeRequested()

  // Cache-busts the lock background by appending `?v=`. Adding a query
  // string keeps Image's loader happy while forcing it to reload when the
  // user picks a new background mid-session.
  function fileUrl(path) {
    if (!path) return ""
    var encoded = String(path).split("/").map(encodeURIComponent).join("/")
    return "file://" + encoded + "?v=" + backgroundVersion
  }

  function forcePasswordFocus() {
    passwordInput.forceActiveFocus()
  }

  function clearPassword() {
    passwordTextEdited("")
  }

  function syncPasswordText() {
    if (passwordInput.text === passwordText) return
    syncingPasswordText = true
    passwordInput.text = passwordText
    syncingPasswordText = false
  }

  function neon(c, a) {
    return Qt.rgba(c.r, c.g, c.b, a)
  }

  function resetAnimation() {
    introAnim.stop()
    outroAnim.stop()
    backdropScale = 1
    blurAmount = 1
    fieldOffset = 0
    fieldScale = 1
    fieldOpacity = 1
    glowStrength = 0
    sweepProgress = 0
    cardOpacity = 0
    backdropSaturation = 0
  }

  function playIntro() {
    if (!animated) {
      resetAnimation()
      return
    }
    outroAnim.stop()
    introAnim.restart()
  }

  onPasswordTextChanged: syncPasswordText()
  onInputEnabledChanged: {
    if (inputEnabled) Qt.callLater(forcePasswordFocus)
  }
  onActiveChanged: if (active) playIntro()
  onUnlockingChanged: {
    if (!unlocking || !animated) return
    introAnim.stop()
    outroAnim.restart()
  }
  Component.onCompleted: {
    syncPasswordText()
    if (inputEnabled) Qt.callLater(forcePasswordFocus)
    if (active) playIntro()
  }

  // Lock: the wallpaper settles in from a zoom while the blur comes up, a neon
  // band sweeps across, and the field rises in with a glow.
  ParallelAnimation {
    id: introAnim
    NumberAnimation { target: root; property: "backdropScale"; from: 1.12; to: 1; duration: 900; easing.type: Easing.OutCubic }
    NumberAnimation { target: root; property: "blurAmount"; from: 0; to: 1; duration: 700; easing.type: Easing.OutCubic }
    NumberAnimation { target: root; property: "sweepProgress"; from: 0; to: 1; duration: 850; easing.type: Easing.InOutQuad }
    SequentialAnimation {
      PropertyAction { target: root; property: "fieldOpacity"; value: 0 }
      PropertyAction { target: root; property: "fieldScale"; value: 1 }
      PauseAnimation { duration: 200 }
      ParallelAnimation {
        NumberAnimation { target: root; property: "fieldOpacity"; from: 0; to: 1; duration: 400; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "fieldOffset"; from: 60; to: 0; duration: 600; easing.type: Easing.OutBack }
      }
    }
    SequentialAnimation {
      PropertyAction { target: root; property: "glowStrength"; value: 0 }
      PauseAnimation { duration: 350 }
      NumberAnimation { target: root; property: "glowStrength"; to: 1; duration: 250; easing.type: Easing.OutQuad }
      NumberAnimation { target: root; property: "glowStrength"; to: 0.35; duration: 600; easing.type: Easing.InOutQuad }
    }
    SequentialAnimation {
      PropertyAction { target: root; property: "cardTitle"; value: "LOCKED" }
      PropertyAction { target: root; property: "cardSubtitle"; value: "Session secured" }
      PropertyAction { target: root; property: "cardColor"; value: root.cardGold }
      PropertyAction { target: root; property: "cardOpacity"; value: 0 }
      PauseAnimation { duration: 150 }
      ParallelAnimation {
        NumberAnimation { target: root; property: "cardScale"; from: 2.2; to: 1; duration: 260; easing.type: Easing.OutBack }
        NumberAnimation { target: root; property: "cardOpacity"; from: 0; to: 1; duration: 160 }
      }
      PauseAnimation { duration: 1100 }
      ParallelAnimation {
        NumberAnimation { target: root; property: "cardOpacity"; to: 0; duration: 350; easing.type: Easing.InQuad }
        NumberAnimation { target: root; property: "cardScale"; to: 0.94; duration: 350; easing.type: Easing.InQuad }
      }
    }
  }

  // Unlock: the field pops and flares, the WELCOME BACK card slams in, the
  // blur clears, and the band sweeps across again before the service releases
  // the lock. Keep the total in step with unlockAnimationTimer in Service.qml.
  ParallelAnimation {
    id: outroAnim
    SequentialAnimation {
      PauseAnimation { duration: 250 }
      NumberAnimation { target: root; property: "blurAmount"; to: 0; duration: 800; easing.type: Easing.InOutCubic }
    }
    NumberAnimation { target: root; property: "backdropScale"; to: 1.04; duration: 1100; easing.type: Easing.InOutQuad }
    SequentialAnimation {
      PauseAnimation { duration: 300 }
      NumberAnimation { target: root; property: "sweepProgress"; from: 0; to: 1; duration: 650; easing.type: Easing.InOutQuad }
    }
    SequentialAnimation {
      PropertyAction { target: root; property: "cardTitle"; value: "WELCOME BACK" }
      PropertyAction { target: root; property: "cardSubtitle"; value: "Mission passed" }
      PropertyAction { target: root; property: "cardColor"; value: root.cardGold }
      PropertyAction { target: root; property: "cardOpacity"; value: 0 }
      PauseAnimation { duration: 120 }
      ParallelAnimation {
        NumberAnimation { target: root; property: "cardScale"; from: 2.2; to: 1; duration: 260; easing.type: Easing.OutBack }
        NumberAnimation { target: root; property: "cardOpacity"; from: 0; to: 1; duration: 160 }
      }
      PauseAnimation { duration: 500 }
      NumberAnimation { target: root; property: "cardOpacity"; to: 0; duration: 200; easing.type: Easing.InQuad }
    }
    SequentialAnimation {
      ParallelAnimation {
        NumberAnimation { target: root; property: "fieldScale"; to: 1.06; duration: 140; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "glowStrength"; to: 1; duration: 140; easing.type: Easing.OutQuad }
      }
      ParallelAnimation {
        NumberAnimation { target: root; property: "fieldScale"; to: 0.88; duration: 300; easing.type: Easing.InQuad }
        NumberAnimation { target: root; property: "fieldOpacity"; to: 0; duration: 300; easing.type: Easing.InQuad }
        NumberAnimation { target: root; property: "glowStrength"; to: 0; duration: 300; easing.type: Easing.InQuad }
      }
    }
  }

  // Measures the masked password at full size; passwordDotScale compares this
  // against the field width to decide how far the dots must shrink to fit.
  TextMetrics {
    id: dotMetrics
    font.family: Style.font.family
    font.pixelSize: root.passwordDotFontSize
    font.letterSpacing: root.passwordDotLetterSpacing
    text: "●".repeat(passwordInput.text.length)
  }

  Rectangle {
    anchors.fill: parent
    color: Commons.Color.background

    // Wrapped so the zoom scales the wallpaper and its blur together.
    Item {
      anchors.fill: parent
      scale: root.backdropScale

      Image {
        id: wallpaper
        anchors.fill: parent
        source: root.loadBackground ? root.fileUrl(root.backgroundPath) : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        sourceSize.width: width
        sourceSize.height: height
      }

      MultiEffect {
        anchors.fill: wallpaper
        source: wallpaper
        autoPaddingEnabled: false
        blurEnabled: root.loadBackground && wallpaper.status === Image.Ready
        blur: root.blurAmount
        blurMax: 128
        blurMultiplier: 1.25
        contrast: -0.08
        saturation: root.backdropSaturation
      }
    }

    // Neon band that sweeps left to right, brightest mid-screen.
    Item {
      anchors.fill: parent
      visible: root.animated && root.sweepProgress > 0 && root.sweepProgress < 1
      opacity: Math.sin(root.sweepProgress * Math.PI)

      Rectangle {
        width: parent.width * 0.45
        height: parent.height
        x: -width + root.sweepProgress * (parent.width + width)
        gradient: Gradient {
          orientation: Gradient.Horizontal
          GradientStop { position: 0.0; color: root.neon(root.neonB, 0) }
          GradientStop { position: 0.45; color: root.neon(root.neonB, 0.22) }
          GradientStop { position: 0.8; color: root.neon(root.neonA, 0.38) }
          GradientStop { position: 1.0; color: root.neon(root.neonA, 0) }
        }
      }

      Rectangle {
        width: parent.width * 0.3
        height: 3
        radius: 1.5
        y: parent.height / 2 + root.fieldOffset
        x: -width + root.sweepProgress * (parent.width + width)
        gradient: Gradient {
          orientation: Gradient.Horizontal
          GradientStop { position: 0.0; color: root.neon(root.neonB, 0) }
          GradientStop { position: 0.7; color: root.neonA }
          GradientStop { position: 1.0; color: "white" }
        }
      }
    }

    // GTA mission card: a dark band with a gold title that slams in on lock
    // and unlock.
    Item {
      anchors.fill: parent
      visible: root.animated && root.cardOpacity > 0
      opacity: root.cardOpacity

      Rectangle {
        width: parent.width
        height: cardTitleText.font.pixelSize * 2.6
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -parent.height * 0.17
        gradient: Gradient {
          GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0) }
          GradientStop { position: 0.5; color: Qt.rgba(0, 0, 0, 0.55) }
          GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0) }
        }
      }

      Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -parent.height * 0.17
        scale: root.cardScale
        spacing: 4

        Text {
          id: cardTitleText
          anchors.horizontalCenter: parent.horizontalCenter
          text: root.cardTitle
          // Pricedown is the GTA title font, installed in ~/.local/share/fonts.
          font.family: "Pricedown"
          font.weight: Font.Black
          font.pixelSize: Math.round(root.height * 0.09)
          font.letterSpacing: 1
          color: root.cardColor
          style: Text.Outline
          styleColor: "#0b0612"
        }

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: root.cardSubtitle
          font.family: "Pricedown"
          font.weight: Font.Black
          font.pixelSize: Math.round(root.height * 0.03)
          font.letterSpacing: 3
          font.capitalization: Font.AllUppercase
          color: "white"
          style: Text.Outline
          styleColor: "#0b0612"
        }
      }
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      onClicked: { root.wakeRequested(); root.forcePasswordFocus() }
      onPositionChanged: root.wakeRequested()
    }

    BorderSurface {
      id: inputField
      width: root.fieldWidth
      height: root.fieldHeight
      anchors.centerIn: parent
      anchors.verticalCenterOffset: root.fieldOffset
      scale: root.fieldScale
      opacity: root.fieldOpacity
      color: Commons.Color.lock.background
      borderSpec: root.inputBorderSpec
      radius: Style.cornerRadius
      clip: true
      layer.enabled: root.animated
      layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: root.neonA
        shadowBlur: 1.0
        shadowHorizontalOffset: 0
        shadowVerticalOffset: 0
        shadowOpacity: root.glowStrength
      }

      TextInput {
        id: passwordInput
        anchors.fill: parent
        anchors.topMargin: inputField.borderTop
        // Reserve the fingerprint icon's width on both sides so the centered
        // dots stay symmetric and never slide under the icon as they grow.
        anchors.rightMargin: inputField.borderRight + 18 + root.fingerprintReserve
        anchors.bottomMargin: inputField.borderBottom
        anchors.leftMargin: inputField.borderLeft + 18 + root.fingerprintReserve
        verticalAlignment: TextInput.AlignVCenter
        horizontalAlignment: TextInput.AlignHCenter
        activeFocusOnPress: true
        clip: true
        enabled: root.inputEnabled && !root.authenticatingPassword
        readOnly: root.authenticatingPassword
        echoMode: TextInput.Password
        passwordCharacter: "\u25CF"
        passwordMaskDelay: 0
        // The wanted stars below draw the mask on the animated theme.
        color: root.animated ? "transparent" : Commons.Color.lock.text
        selectionColor: Commons.Color.lock.selection
        selectedTextColor: Commons.Color.lock.text
        font.family: Style.font.family
        font.pixelSize: text.length > 0 ? Math.max(1, Math.floor(root.passwordDotFontSize * root.passwordDotScale)) : root.fieldFontSize
        font.letterSpacing: text.length > 0 ? root.passwordDotLetterSpacing * root.passwordDotScale : 0
        cursorVisible: activeFocus && root.showPasswordCursor && text.length > 0 && !root.animated
        cursorDelegate: Rectangle {
          width: 2
          color: Commons.Color.lock.text
          visible: passwordInput.cursorVisible
        }

        onTextChanged: {
          if (!root.syncingPasswordText) root.passwordTextEdited(text)
          if (text.length > 0) {
            root.wakeRequested()
            if (root.starFlashing) root.stopStarFlash()
          }
          if (text.length > 0 && root.failureMessage.length > 0) root.clearFailureRequested()
        }

        onAccepted: {
          var submitted = root.passwordText
          root.lastSubmittedLength = submitted.length
          root.passwordTextEdited("")
          if (submitted.length > 0) root.submitPassword(submitted)
        }

        Keys.onPressed: function(event) {
          root.wakeRequested()
          if (event.key === Qt.Key_Escape || (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_U)) {
            root.passwordTextEdited("")
            event.accepted = true
          }
        }
      }

      // GTA wanted stars stand in for the password dots, each popping in as
      // it is typed.
      Row {
        anchors.centerIn: passwordInput
        anchors.horizontalCenterOffset: root.starFlashing ? Math.sin(root.flashStep * Math.PI * 2) * 6 * (1 - root.flashStep / 6) : 0
        visible: root.animated && root.starCount > 0
        spacing: root.starSize * 0.25

        Repeater {
          model: root.animated ? root.starCount : 0

          Text {
            text: ""
            font.family: Style.font.family
            font.pixelSize: root.starSize
            color: root.starFlashing ? (Math.floor(root.flashStep) % 2 === 0 ? root.flashRed : root.flashBlue) : "white"
            opacity: root.starFlashing ? 1 - Math.max(0, root.flashStep - 5) : 1
            style: Text.Outline
            styleColor: "#0b0612"
            transformOrigin: Item.Center

            SequentialAnimation on scale {
              NumberAnimation { from: 0; to: 1.4; duration: 110; easing.type: Easing.OutQuad }
              NumberAnimation { to: 1; duration: 160; easing.type: Easing.OutBack }
            }
          }
        }
      }

      Text {
        textFormat: Text.PlainText
        anchors.fill: passwordInput
        text: root.authenticatingPassword ? "Checking…" : (root.failureMessage.length > 0 ? root.failureMessage : root.placeholderText)
        visible: passwordInput.text.length === 0 && !root.starFlashing
        color: root.authenticatingPassword ? Commons.Color.lock.text : (root.failureMessage.length > 0 ? Commons.Color.lock.textError : Commons.Color.lock.placeholder)
        font.family: Style.font.family
        font.pixelSize: root.fieldFontSize
        font.italic: !root.authenticatingPassword && root.failureMessage.length > 0
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
      }

      // Fingerprint hint pinned inside the field's right edge when a sensor is
      // enrolled, so the user knows they can touch to unlock instead of typing.
      // Matches hyprlock, which draws its fingerprint icon in the same spot.
      Text {
        id: fingerprintIcon
        objectName: "fingerprintIndicator"
        anchors.right: parent.right
        anchors.rightMargin: inputField.borderRight + 18
        anchors.verticalCenter: parent.verticalCenter
        visible: root.fingerprintConfigured
        text: "󰈷"
        color: Commons.Color.lock.placeholder
        font.family: Style.font.family
        font.pixelSize: Math.round(root.fieldFontSize * 1.1)
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
      }
    }
  }
}
