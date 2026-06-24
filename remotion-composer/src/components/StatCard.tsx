import {
  AbsoluteFill,
  interpolate,
  spring,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";

interface StatCardProps {
  stat: string;
  subtitle?: string;
  statFontSize?: number;
  subtitleFontSize?: number;
  color?: string;
  accentColor?: string;
  backgroundColor?: string;
}

// Splits a stat string into a static prefix, the first number, and a suffix —
// e.g. "Over 100 million" -> ["Over ", "100", " million"], "8.1B" -> ["","8.1","B"].
function parseStat(stat: string): { prefix: string; num: string; suffix: string } | null {
  const m = stat.match(/^(.*?)(\d[\d,]*(?:\.\d+)?)(.*)$/s);
  if (!m) return null;
  return { prefix: m[1], num: m[2], suffix: m[3] };
}

function formatNumber(value: number, template: string): string {
  const hasComma = template.includes(",");
  const decimals = template.includes(".")
    ? template.split(".")[1].length
    : 0;
  const fixed = value.toFixed(decimals);
  if (!hasComma) return fixed;
  const [intPart, decPart] = fixed.split(".");
  const withCommas = intPart.replace(/\B(?=(\d{3})+(?!\d))/g, ",");
  return decPart ? `${withCommas}.${decPart}` : withCommas;
}

export const StatCard: React.FC<StatCardProps> = ({
  stat,
  subtitle,
  color = "#F8FAFC",
  accentColor = "#22D3EE",
}) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const push =
    1 + interpolate(frame, [0, 150], [0, 0.05], { extrapolateRight: "clamp" });

  // Reveal/ease driver for the whole block.
  const reveal = spring({
    frame,
    fps,
    config: { damping: 18, stiffness: 80, mass: 0.9 },
  });

  // Count-up: ease a number from 0 to its target over ~1s.
  const parsed = parseStat(stat);
  const countT = spring({
    frame: frame - 4,
    fps,
    config: { damping: 30, stiffness: 60 },
  });
  let display = stat;
  if (parsed) {
    const target = parseFloat(parsed.num.replace(/,/g, ""));
    const current = target * countT;
    display = `${parsed.prefix}${formatNumber(current, parsed.num)}${parsed.suffix}`;
  }

  // Size to fit: long phrases shrink so they stay on the left column.
  const len = stat.length;
  const size = len > 40 ? 76 : len > 20 ? 120 : 168;

  const ruleH = interpolate(
    spring({ frame: frame - 4, fps, config: { damping: 16, stiffness: 70 } }),
    [0, 1],
    [0, size * 1.4]
  );

  const subOpacity = spring({ frame: frame - 16, fps, config: { damping: 22 } });

  return (
    <AbsoluteFill
      style={{ justifyContent: "center", alignItems: "flex-start", padding: "0 120px 0 150px" }}
    >
      <AbsoluteFill
        style={{
          pointerEvents: "none",
          background: `radial-gradient(ellipse 50% 42% at 34% 50%, ${accentColor}26 0%, transparent 70%)`,
        }}
      />
      <div
        style={{
          transform: `scale(${push})`,
          transformOrigin: "20% 50%",
          display: "flex",
          gap: 34,
          alignItems: "stretch",
          maxWidth: "86%",
        }}
      >
        <div
          style={{
            width: 5,
            alignSelf: "center",
            height: ruleH,
            background: `linear-gradient(180deg, ${accentColor}, ${accentColor}00)`,
            borderRadius: 3,
            boxShadow: `0 0 24px ${accentColor}66`,
          }}
        />
        <div>
          <div
            style={{
              fontSize: size,
              fontWeight: 800,
              lineHeight: 1.0,
              letterSpacing: "-0.035em",
              color: accentColor,
              fontVariantNumeric: "tabular-nums",
              opacity: reveal,
              transform: `translateY(${interpolate(reveal, [0, 1], [24, 0])}px)`,
              textShadow: "0 12px 48px rgba(0,0,0,0.5)",
            }}
          >
            {display}
          </div>
          {subtitle && (
            <div
              style={{
                marginTop: 22,
                opacity: subOpacity,
                transform: `translateY(${interpolate(subOpacity, [0, 1], [16, 0])}px)`,
                fontSize: 30,
                fontWeight: 400,
                color,
                maxWidth: 900,
                lineHeight: 1.3,
              }}
            >
              {subtitle}
            </div>
          )}
        </div>
      </div>
    </AbsoluteFill>
  );
};
