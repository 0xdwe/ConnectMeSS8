import logoImg from '../../imports/image-removebg-preview_(6).png';

interface TopHeaderProps {
  userName: string;
  userAvatar: string;
  onProfileClick: () => void;
}

export function TopHeader({ userName, userAvatar, onProfileClick }: TopHeaderProps) {
  return (
    <header
      className="fixed top-0 left-0 right-0 z-50 transition-all shadow-lg"
      style={{
        backgroundColor: '#7C34ED',
      }}
    >
      <div className="flex justify-between items-center h-16 px-4">
        <div className="flex items-center gap-3">
          <img
            src={logoImg}
            alt="Connect Me"
            className="h-8"
            style={{ width: 'auto' }}
          />
          <span className="font-bold text-lg text-white">Connect Me</span>
        </div>
        <button
          onClick={onProfileClick}
          className="w-10 h-10 rounded-full flex items-center justify-center text-2xl hover:scale-110 transition-all bg-white/20 backdrop-blur-sm border-2 border-white/40"
          aria-label="View profile"
        >
          {userAvatar}
        </button>
      </div>
    </header>
  );
}
