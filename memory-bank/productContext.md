# Product Context: Copilot Button

## 1. Problem Space

In 2024, Microsoft introduced the hardware Copilot key across consumer and enterprise laptops. Unlike traditional standalone scan codes, manufacturers implemented the Copilot key as a synthetic composite macro:
$$\text{VK\_LWIN} \rightarrow \text{VK\_LSHIFT} \rightarrow \text{VK\_F23}$$

This hardware implementation introduced several user experience flaws:
1. **Unwanted Start Menu Flashes**: Because the Windows key is dispatched before `F23`, releasing the key or interrupting the sequence causes the OS to register a standalone Windows key press, popping up the Start Menu.
2. **Modifier Key Leakage & Input Sticking**: Generic keyboard remappers often leave modifier keys stuck down in the OS keyboard buffer, disrupting subsequent typing or gameplay.
3. **Typing Latency**: Naive interceptors introduce noticeable input lag (50–100 ms) to every normal `Win` or `Shift` keypress while waiting to verify whether a Copilot key sequence follows.
4. **Wasted Keyboard Real Estate**: Users who do not use Microsoft Copilot are left with an unprogrammable physical key taking up prime space on their keyboard.

---

## 2. Solution & Value Proposition

`Copilot Button` transforms an intrusive or unused hardware key into a programmable multifunction button without degrading normal keyboard performance:

- **Invisible Interception**: Eliminates Start Menu flashes while maintaining instantaneous response times for standard Windows shortcuts (`Win+R`, `Win+E`) via microsecond-level state machine buffering (25 ms / 15 ms) and fast-path dispatch.
- **Multifunction Gestures**: Maps up to 5 distinct actions to a single physical key:
  - Single tap: Quick mute (Microphone toggle).
  - Double tap: Media Play / Pause.
  - Triple tap: Next Track.
  - Quadruple tap: Customizable action or None.
  - Press-and-hold: Push-to-Talk or developer terminal launch.
- **Native Look & Feel**: The On-Screen Display (OSD) adheres to Windows 11 Fluent design principles, using native DWM rounded corners and smooth alpha transitions that feel like an integrated part of the operating system.
- **Set-and-Forget Reliability**: Standalone binary that automatically places itself in `%LOCALAPPDATA%`, configures elevated startup via Task Scheduler without UAC prompts, registers an uninstaller in Windows Settings, and updates settings in real time via file watching.

