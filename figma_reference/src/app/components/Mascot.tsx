interface MascotProps {
  color: string;
  emotion?: 'happy' | 'excited' | 'neutral' | 'love' | 'cool' | 'sleepy' | 'surprised';
  size?: 'sm' | 'md' | 'lg' | 'xl';
  className?: string;
}

export function Mascot({ color, emotion = 'happy', size = 'md', className = '' }: MascotProps) {
  const sizeMap = {
    sm: 'w-12 h-12',
    md: 'w-16 h-16',
    lg: 'w-24 h-24',
    xl: 'w-32 h-32'
  };

  const eyeSizeMap = {
    sm: 4,
    md: 6,
    lg: 8,
    xl: 10
  };

  const eyeSize = eyeSizeMap[size];

  const renderFace = () => {
    switch (emotion) {
      case 'happy':
        return (
          <>
            <div className="absolute" style={{ top: '35%', left: '30%', width: `${eyeSize}px`, height: `${eyeSize}px`, backgroundColor: '#1B1B1B', borderRadius: '50%' }} />
            <div className="absolute" style={{ top: '35%', right: '30%', width: `${eyeSize}px`, height: `${eyeSize}px`, backgroundColor: '#1B1B1B', borderRadius: '50%' }} />
            <div className="absolute" style={{ bottom: '30%', left: '50%', transform: 'translateX(-50%)', width: `${eyeSize * 2}px`, height: `${eyeSize}px`, borderBottom: '2px solid #1B1B1B', borderRadius: '0 0 50px 50px' }} />
          </>
        );
      case 'excited':
        return (
          <>
            <div className="absolute" style={{ top: '35%', left: '30%', width: `${eyeSize}px`, height: `${eyeSize * 1.5}px`, backgroundColor: '#1B1B1B', borderRadius: '50%' }} />
            <div className="absolute" style={{ top: '35%', right: '30%', width: `${eyeSize}px`, height: `${eyeSize * 1.5}px`, backgroundColor: '#1B1B1B', borderRadius: '50%' }} />
            <div className="absolute" style={{ bottom: '25%', left: '50%', transform: 'translateX(-50%)', width: `${eyeSize * 2.5}px`, height: `${eyeSize * 1.5}px`, backgroundColor: '#1B1B1B', borderRadius: '50%' }} />
          </>
        );
      case 'love':
        return (
          <>
            <div className="absolute" style={{ top: '35%', left: '30%', width: `${eyeSize}px`, height: `${eyeSize}px`, color: '#FF7B9C', fontSize: `${eyeSize}px` }}>♥</div>
            <div className="absolute" style={{ top: '35%', right: '30%', width: `${eyeSize}px`, height: `${eyeSize}px`, color: '#FF7B9C', fontSize: `${eyeSize}px` }}>♥</div>
            <div className="absolute" style={{ bottom: '30%', left: '50%', transform: 'translateX(-50%)', width: `${eyeSize * 2}px`, height: `${eyeSize}px`, borderBottom: '2px solid #1B1B1B', borderRadius: '0 0 50px 50px' }} />
          </>
        );
      case 'cool':
        return (
          <>
            <div className="absolute" style={{ top: '35%', left: '25%', width: `${eyeSize * 2}px`, height: `${eyeSize / 2}px`, backgroundColor: '#1B1B1B', borderRadius: '2px' }} />
            <div className="absolute" style={{ top: '35%', right: '25%', width: `${eyeSize * 2}px`, height: `${eyeSize / 2}px`, backgroundColor: '#1B1B1B', borderRadius: '2px' }} />
            <div className="absolute" style={{ bottom: '30%', left: '50%', transform: 'translateX(-50%)', width: `${eyeSize * 1.5}px`, height: `${eyeSize / 2}px`, backgroundColor: '#1B1B1B', borderRadius: '2px' }} />
          </>
        );
      case 'sleepy':
        return (
          <>
            <div className="absolute" style={{ top: '40%', left: '30%', width: `${eyeSize}px`, height: `${eyeSize / 3}px`, backgroundColor: '#1B1B1B', borderRadius: '2px' }} />
            <div className="absolute" style={{ top: '40%', right: '30%', width: `${eyeSize}px`, height: `${eyeSize / 3}px`, backgroundColor: '#1B1B1B', borderRadius: '2px' }} />
            <div className="absolute" style={{ bottom: '35%', left: '50%', transform: 'translateX(-50%)', width: `${eyeSize}px`, height: `${eyeSize}px`, borderRadius: '50%', border: '1px solid #1B1B1B' }} />
          </>
        );
      case 'surprised':
        return (
          <>
            <div className="absolute" style={{ top: '35%', left: '30%', width: `${eyeSize * 1.2}px`, height: `${eyeSize * 1.2}px`, backgroundColor: '#1B1B1B', borderRadius: '50%' }} />
            <div className="absolute" style={{ top: '35%', right: '30%', width: `${eyeSize * 1.2}px`, height: `${eyeSize * 1.2}px`, backgroundColor: '#1B1B1B', borderRadius: '50%' }} />
            <div className="absolute" style={{ bottom: '28%', left: '50%', transform: 'translateX(-50%)', width: `${eyeSize * 1.5}px`, height: `${eyeSize * 1.5}px`, backgroundColor: '#1B1B1B', borderRadius: '50%' }} />
          </>
        );
      case 'neutral':
      default:
        return (
          <>
            <div className="absolute" style={{ top: '38%', left: '30%', width: `${eyeSize}px`, height: `${eyeSize}px`, backgroundColor: '#1B1B1B', borderRadius: '50%' }} />
            <div className="absolute" style={{ top: '38%', right: '30%', width: `${eyeSize}px`, height: `${eyeSize}px`, backgroundColor: '#1B1B1B', borderRadius: '50%' }} />
            <div className="absolute" style={{ bottom: '32%', left: '50%', transform: 'translateX(-50%)', width: `${eyeSize * 2}px`, height: `${eyeSize / 3}px`, backgroundColor: '#1B1B1B', borderRadius: '2px' }} />
          </>
        );
    }
  };

  return (
    <div className={`${sizeMap[size]} ${className} relative`}>
      <svg viewBox="0 0 100 100" className="w-full h-full">
        <defs>
          <filter id={`blob-shadow-${color}`} x="-50%" y="-50%" width="200%" height="200%">
            <feGaussianBlur in="SourceAlpha" stdDeviation="3" />
            <feOffset dx="0" dy="2" result="offsetblur" />
            <feComponentTransfer>
              <feFuncA type="linear" slope="0.2" />
            </feComponentTransfer>
            <feMerge>
              <feMergeNode />
              <feMergeNode in="SourceGraphic" />
            </feMerge>
          </filter>
        </defs>
        <path
          d="M50,10 C60,10 70,15 78,25 C86,35 90,45 90,55 C90,65 86,75 78,82 C70,89 60,93 50,93 C40,93 30,89 22,82 C14,75 10,65 10,55 C10,45 14,35 22,25 C30,15 40,10 50,10 Z"
          fill={color}
          filter={`url(#blob-shadow-${color})`}
          opacity="0.9"
        />
      </svg>
      {renderFace()}
    </div>
  );
}
