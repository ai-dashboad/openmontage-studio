import {
  AbsoluteFill,
  interpolate,
  spring,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";

interface HeroTitleProps {
  title: string;
  subtitle?: string;
  accent?: string;
}

// A word that rises out from behind a mask — the staggered, eased reveal that
// reads as "designed motion graphics" rather than a fade.
const RevealWord: React.FC<{
  word: string;
  delay: number;
  color: string;
}> = ({ word, delay, color }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const s = spring({
    frame: frame - delay,
    fps,
    config: { damping: 18, stiffness: 90, mass: 0.8 },
  });
  return (
    <span
      style={{
        display: "inline-block",
        overflow: "hidden",
        verticalAlign: "top",
        paddingBottom: "0.08em",
      }}
    >
      <span
        style={{
          display: "inline-block",
          transform: `translateY(${interpolate(s, [0, 1], [105, 0])}%)`,
          color,
        }}
      >
        {word}
        {" "}
      </span>
    </span>
  );
};

export const HeroTitle: React.FC<HeroTitleProps> = ({
  title,
  subtitle,
  accent = "#22D3EE",
}) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  // Continuous, almost-imperceptible push-in so nothing is ever fully static.
  const push =
    1 + interpolate(frame, [0, 150], [0, 0.05], { extrapolateRight: "clamp" });

  const words = title.split(" ");
  // Headline scales with length so long titles still fit the left column.
  const size = title.length > 40 ? 72 : title.length > 22 ? 92 : 108;

  // Left accent rule draws up from nothing.
  const ruleH = interpolate(
    spring({ frame: frame - 4, fps, config: { damping: 16, stiffness: 70 } }),
    [0, 1],
    [0, size * 1.5]
  );

  const subDelay = words.length * 3 + 8;
  const subOpacity = spring({
    frame: frame - subDelay,
    fps,
    config: { damping: 20 },
  });

  return (
    <AbsoluteFill
      style={{
        justifyContent: "center",
        alignItems: "flex-start",
        padding: "0 120px 0 150px",
      }}
    >
      {/* Soft radial glow anchoring the headline (depth). */}
      <AbsoluteFill
        style={{
          pointerEvents: "none",
          background: `radial-gradient(ellipse 50% 40% at 32% 50%, ${accent}22 0%, transparent 70%)`,
        }}
      />

      <div
        style={{
          transform: `scale(${push})`,
          transformOrigin: "20% 50%",
          display: "flex",
          alignItems: "stretch",
          gap: 34,
          maxWidth: "82%",
        }}
      >
        {/* Vertical accent motif */}
        <div
          style={{
            width: 5,
            alignSelf: "center",
            height: ruleH,
            background: `linear-gradient(180deg, ${accent}, ${accent}00)`,
            borderRadius: 3,
            boxShadow: `0 0 24px ${accent}66`,
          }}
        />

        <div>
          <div
            style={{
              fontSize: size,
              fontWeight: 800,
              lineHeight: 1.03,
              letterSpacing: "-0.03em",
              color: "#F8FAFC",
              textShadow: "0 12px 48px rgba(0,0,0,0.55)",
            }}
          >
            {words.map((w, i) => (
              <RevealWord key={i} word={w} delay={i * 3} color="#F8FAFC" />
            ))}
          </div>

          {subtitle && (
            <div
              style={{
                marginTop: 26,
                opacity: subOpacity,
                transform: `translateY(${interpolate(subOpacity, [0, 1], [16, 0])}px)`,
                fontSize: 22,
                fontWeight: 600,
                color: accent,
                letterSpacing: "0.22em",
                textTransform: "uppercase",
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
