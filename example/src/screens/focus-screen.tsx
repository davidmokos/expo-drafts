import { Button, Column, FieldGroup, Host, Picker, Row, Slider, Spacer, Text } from '@expo/ui';
import { accessibilityLabel, font, monospacedDigit } from '@expo/ui/swift-ui/modifiers';
import { useEffect, useState } from 'react';
import { AppState, Platform, useColorScheme } from 'react-native';

import { preview } from '../data/preview';

type Session = 'focus' | 'break';
type Phase = 'ready' | 'running' | 'paused' | 'completed';

const focusDurations = [...new Set([5, 15, 25, 50, preview.focusMinutes])].sort((a, b) => a - b);

function formatRemaining(milliseconds: number) {
  const seconds = Math.ceil(Math.max(0, milliseconds) / 1000);
  return `${Math.floor(seconds / 60)
    .toString()
    .padStart(2, '0')}:${(seconds % 60).toString().padStart(2, '0')}`;
}

export default function FocusScreen() {
  const [focusMinutes, setFocusMinutes] = useState(preview.focusMinutes);
  const [breakMinutes, setBreakMinutes] = useState(preview.breakMinutes);
  const [session, setSession] = useState<Session>('focus');
  const [phase, setPhase] = useState<Phase>('ready');
  const [remaining, setRemaining] = useState(preview.focusMinutes * 60_000);
  const [deadline, setDeadline] = useState<number | null>(null);
  const dark = useColorScheme() === 'dark';
  const secondary = dark ? '#98989D' : '#6D6D72';
  const active = phase === 'running' || phase === 'paused';
  const duration = (session === 'focus' ? focusMinutes : breakMinutes) * 60_000;

  useEffect(() => {
    if (deadline === null) return;

    // A deadline keeps the countdown correct when JavaScript is suspended.
    const synchronize = () => {
      const next = Math.max(0, deadline - Date.now());
      setRemaining(next);
      if (next === 0) {
        setDeadline(null);
        setPhase('completed');
      }
    };

    synchronize();
    const interval = setInterval(synchronize, 1000);
    const subscription = AppState.addEventListener('change', (state) => {
      if (state === 'active') synchronize();
    });
    return () => {
      clearInterval(interval);
      subscription.remove();
    };
  }, [deadline]);

  const start = () => {
    const next = phase === 'completed' ? duration : remaining;
    setRemaining(next);
    setDeadline(Date.now() + next);
    setPhase('running');
  };

  const pause = () => {
    const next = Math.max(0, (deadline ?? Date.now()) - Date.now());
    setRemaining(next);
    setDeadline(null);
    setPhase(next === 0 ? 'completed' : 'paused');
  };

  const reset = () => {
    setDeadline(null);
    setRemaining(duration);
    setPhase('ready');
  };

  const startOtherSession = () => {
    const nextSession = session === 'focus' ? 'break' : 'focus';
    const next = (nextSession === 'focus' ? focusMinutes : breakMinutes) * 60_000;
    setSession(nextSession);
    setRemaining(next);
    setDeadline(Date.now() + next);
    setPhase('running');
  };

  const changeFocusMinutes = (minutes: number) => {
    setFocusMinutes(minutes);
    if (session === 'focus') {
      setRemaining(minutes * 60_000);
      setPhase('ready');
    }
  };

  const changeBreakMinutes = (minutes: number) => {
    setBreakMinutes(minutes);
    if (session === 'break') {
      setRemaining(minutes * 60_000);
      setPhase('ready');
    }
  };

  const sessionName = session === 'focus' ? 'Focus session' : 'Break';
  const status = {
    ready: session === 'focus' ? 'Make room for one thing.' : 'A moment to recharge.',
    running: session === 'focus' ? 'One thing at a time.' : 'Step away for a moment.',
    paused: "Paused. Continue when you're ready.",
    completed:
      session === 'focus'
        ? 'Focus complete. Time for a break.'
        : 'Break complete. Ready for a fresh start.',
  }[phase];
  const startLabel = {
    ready: 'Start',
    running: 'Pause',
    paused: 'Resume',
    completed: 'Start again',
  }[phase];

  return (
    <Host style={{ flex: 1 }} seedColor={preview.tint}>
      <FieldGroup>
        <FieldGroup.Section>
          <Column alignment="center" spacing={8} style={{ paddingVertical: 16 }}>
            <Text textStyle={{ color: secondary }}>{sessionName}</Text>
            <Text
              testID="focus-countdown"
              textStyle={{ fontSize: 56, fontWeight: '300' }}
              modifiers={
                Platform.OS === 'ios'
                  ? [font({ size: 56, weight: 'light', design: 'rounded' }), monospacedDigit()]
                  : undefined
              }>
              {formatRemaining(remaining)}
            </Text>
            <Text textStyle={{ color: secondary, textAlign: 'center' }}>{status}</Text>
          </Column>
          <Row alignment="center" spacing={12}>
            <Button
              label={startLabel}
              testID="focus-start-pause"
              onPress={phase === 'running' ? pause : start}
            />
            <Spacer flexible />
            <Button label="Reset" variant="text" disabled={phase === 'ready'} onPress={reset} />
          </Row>
        </FieldGroup.Section>

        <FieldGroup.Section title="Focus">
          <Row alignment="center" spacing={12}>
            <Text>Duration</Text>
            <Spacer flexible />
            <Picker
              selectedValue={focusMinutes}
              onValueChange={changeFocusMinutes}
              enabled={!active}
              testID="focus-duration">
              {focusDurations.map((minutes) => (
                <Picker.Item key={minutes} label={`${minutes} minutes`} value={minutes} />
              ))}
            </Picker>
          </Row>
          <FieldGroup.SectionFooter>
            <Text>The countdown keeps time while the app is in the background.</Text>
          </FieldGroup.SectionFooter>
        </FieldGroup.Section>

        <FieldGroup.Section title="Break">
          <Row alignment="center" spacing={12}>
            <Text>Duration</Text>
            <Spacer flexible />
            <Text textStyle={{ color: secondary }}>{`${breakMinutes} minutes`}</Text>
          </Row>
          <Slider
            value={breakMinutes}
            min={1}
            max={Math.max(15, preview.breakMinutes)}
            step={1}
            disabled={active}
            onValueChange={changeBreakMinutes}
            testID="break-duration"
            modifiers={
              Platform.OS === 'ios' ? [accessibilityLabel('Break duration in minutes')] : undefined
            }
          />
          <Button
            label={session === 'focus' ? 'Start a break' : 'Start focusing'}
            variant="text"
            disabled={active}
            onPress={startOtherSession}
          />
        </FieldGroup.Section>
      </FieldGroup>
    </Host>
  );
}
