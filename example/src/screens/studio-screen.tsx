import { Button, FieldGroup, Host, Icon, Picker, Row, Slider, Spacer, Text } from '@expo/ui';
import {
  accessibilityHidden,
  accessibilityLabel,
  accessibilityValue,
  font,
  textSelection,
} from '@expo/ui/swift-ui/modifiers';
import { useState } from 'react';
import { Platform } from 'react-native';

import { preview } from '../data/preview';

// The universal controls cover the form; the system color picker is iOS-only.
const ColorPicker =
  Platform.OS === 'ios'
    ? (require('@expo/ui/swift-ui') as typeof import('@expo/ui/swift-ui')).ColorPicker
    : null;

function normalizeColor(value: string) {
  return /^#[\da-f]{6}([\da-f]{2})?$/i.test(value) ? value.slice(0, 7).toUpperCase() : '#287FA3';
}

function mixColor(value: string, amount: number) {
  const color = normalizeColor(value);
  const destination = amount < 0 ? 0 : 255;
  const fraction = Math.min(1, Math.abs(amount) / 100);
  return (
    '#' +
    [1, 3, 5]
      .map((offset) => {
        const channel = Number.parseInt(color.slice(offset, offset + 2), 16);
        return Math.round(channel + (destination - channel) * fraction)
          .toString(16)
          .padStart(2, '0');
      })
      .join('')
      .toUpperCase()
  );
}

const initialColor = normalizeColor(preview.colorHex);
const palettes = [
  { name: preview.palette, color: initialColor },
  ...[
    { name: 'Ocean', color: '#287FA3' },
    { name: 'Orchard', color: '#527A3B' },
    { name: 'Sunset', color: '#D06444' },
  ].filter((palette) => palette.name.toLowerCase() !== preview.palette.toLowerCase()),
];

function ColorRow({ name, color, testID }: { name: string; color: string; testID: string }) {
  return (
    <Row alignment="center" spacing={12} testID={testID}>
      <Icon name="circle.fill" color={color} size={30} modifiers={[accessibilityHidden()]} />
      <Text>{name}</Text>
      <Spacer />
      <Text modifiers={[font({ textStyle: 'body', design: 'monospaced' }), textSelection(true)]}>
        {color}
      </Text>
    </Row>
  );
}

export default function StudioScreen() {
  const [palette, setPalette] = useState(preview.palette);
  const [color, setColor] = useState(initialColor);
  const [lightness, setLightness] = useState(0);
  const mixedColor = mixColor(color, lightness);
  const lightnessLabel = `${lightness > 0 ? '+' : ''}${Math.round(lightness)}%`;
  const changed = palette !== preview.palette || color !== initialColor || lightness !== 0;

  function selectPalette(name: string) {
    const selected = palettes.find((item) => item.name === name);
    if (!selected) return;
    setPalette(selected.name);
    setColor(selected.color);
    setLightness(0);
  }

  function reset() {
    setPalette(preview.palette);
    setColor(initialColor);
    setLightness(0);
  }

  if (!ColorPicker) {
    return (
      <Host style={{ flex: 1 }}>
        <Text>Studio is available on iOS.</Text>
      </Host>
    );
  }

  return (
    <Host style={{ flex: 1 }} seedColor={preview.tint}>
      <FieldGroup testID="studio-form">
        <FieldGroup.Section title={preview.studioTitle}>
          <ColorRow name="Current color" color={mixedColor} testID="studio-current-color" />
          <FieldGroup.SectionFooter>
            <Text>
              Choose a palette, explore a color, and adjust its lightness. Touch and hold a hex code
              to copy it.
            </Text>
          </FieldGroup.SectionFooter>
        </FieldGroup.Section>

        <FieldGroup.Section title="Palette">
          <Row alignment="center">
            <Text>Preset</Text>
            <Spacer />
            <Picker selectedValue={palette} onValueChange={selectPalette} testID="studio-palette">
              {palettes.map((item) => (
                <Picker.Item key={item.name} label={item.name} value={item.name} />
              ))}
              {palette === 'Custom' && <Picker.Item label="Custom" value="Custom" />}
            </Picker>
          </Row>
          <ColorPicker
            label="Color"
            selection={color}
            supportsOpacity={false}
            onSelectionChange={(value) => {
              setColor(normalizeColor(value));
              setPalette('Custom');
              setLightness(0);
            }}
            testID="studio-color-picker"
          />
        </FieldGroup.Section>

        <FieldGroup.Section title="Lightness">
          <Row alignment="center">
            <Text>Adjustment</Text>
            <Spacer />
            <Text>{lightnessLabel}</Text>
          </Row>
          <Slider
            value={lightness}
            onValueChange={setLightness}
            min={-50}
            max={50}
            step={1}
            testID="studio-lightness"
            modifiers={[accessibilityLabel('Color lightness'), accessibilityValue(lightnessLabel)]}
          />
        </FieldGroup.Section>

        <FieldGroup.Section title="Swatches">
          <ColorRow name="Shade" color={mixColor(mixedColor, -25)} testID="studio-shade" />
          <ColorRow name="Color" color={mixedColor} testID="studio-swatch" />
          <ColorRow name="Tint" color={mixColor(mixedColor, 35)} testID="studio-tint" />
        </FieldGroup.Section>

        <FieldGroup.Section>
          <Button
            label="Reset palette"
            variant="text"
            onPress={reset}
            disabled={!changed}
            testID="studio-reset"
          />
        </FieldGroup.Section>
      </FieldGroup>
    </Host>
  );
}
