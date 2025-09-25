export const EXP_SCALER = 1_000_000_000_000n; // 1e12

/**
 * 将人类可读小数字符串转换为 scaled BigInt (human * EXP_SCALER)
 * 例: "0.0000000031" -> 3100n
 */
export function toScaled(human: string): bigint {
  if (!human) throw new Error('empty value');
  const negative = human.startsWith('-');
  if (negative) throw new Error('negative not supported');
  const parts = human.split('.');
  if (parts.length > 2) throw new Error('invalid decimal');
  const intPart = parts[0] || '0';
  const fracRaw = parts[1] || '';
  const frac = (fracRaw + '0'.repeat(12)).slice(0, 12); // pad / truncate
  const scaled = BigInt(intPart) * EXP_SCALER + BigInt(frac);
  return scaled;
}

/**
 * 将 scaled 值转为人类可读字符串
 */
export function fromScaled(scaled: bigint): string {
  const intPart = scaled / EXP_SCALER;
  let frac = (scaled % EXP_SCALER).toString().padStart(12, '0');
  frac = frac.replace(/0+$/, '');
  return frac.length ? `${intPart}.${frac}` : intPart.toString();
}
