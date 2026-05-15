import { X, Upload, Smile } from 'lucide-react';
import { useState } from 'react';

interface EditUserProfileModalProps {
  user: {
    name: string;
    email: string;
    avatar: string;
  };
  onClose: () => void;
  onSave: (updates: { name: string; email: string; avatar: string }) => void;
}

export function EditUserProfileModal({ user, onClose, onSave }: EditUserProfileModalProps) {
  const [name, setName] = useState(user.name);
  const [email, setEmail] = useState(user.email);
  const [avatar, setAvatar] = useState(user.avatar);
  const [avatarType, setAvatarType] = useState<'emoji' | 'image'>(user.avatar.startsWith('http') || user.avatar.startsWith('data:') ? 'image' : 'emoji');

  const handleImageUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      const reader = new FileReader();
      reader.onloadend = () => {
        setAvatar(reader.result as string);
        setAvatarType('image');
      };
      reader.readAsDataURL(file);
    }
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    onSave({ name, email, avatar });
    onClose();
  };

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4 overflow-y-auto">
      <div className="bg-white dark:bg-gray-800 rounded-2xl max-w-md w-full p-6 my-8 transition-colors max-h-[90vh] overflow-y-auto">
        <div className="flex justify-between items-center mb-4 sticky top-0 bg-white dark:bg-gray-800 z-10 pb-2">
          <h2 className="text-xl font-semibold dark:text-white">Edit Profile</h2>
          <button onClick={onClose} className="p-1 hover:bg-gray-100 dark:hover:bg-gray-700 rounded-full dark:text-white">
            <X size={24} />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="space-y-4">
          {/* Profile Picture */}
          <div className="flex flex-col items-center">
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-3">Profile Picture</label>

            {/* Avatar Preview */}
            <div className="w-24 h-24 rounded-full bg-gray-100 dark:bg-gray-700 flex items-center justify-center mb-3 overflow-hidden border-2 border-gray-300 dark:border-gray-600">
              {avatarType === 'emoji' ? (
                <span className="text-5xl">{avatar}</span>
              ) : (
                <img src={avatar} alt="Profile" className="w-full h-full object-cover" />
              )}
            </div>

            {/* Avatar Type Selector */}
            <div className="flex gap-2 mb-3">
              <button
                type="button"
                onClick={() => setAvatarType('emoji')}
                className={`flex items-center gap-2 px-4 py-2 rounded-lg border transition-colors ${
                  avatarType === 'emoji'
                    ? 'border-purple-400 bg-purple-50 dark:bg-purple-900/20 text-purple-600 dark:text-purple-300'
                    : 'border-gray-300 dark:border-gray-600 text-gray-700 dark:text-gray-300'
                }`}
              >
                <Smile size={18} />
                <span className="text-sm">Emoji</span>
              </button>
              <button
                type="button"
                onClick={() => setAvatarType('image')}
                className={`flex items-center gap-2 px-4 py-2 rounded-lg border transition-colors ${
                  avatarType === 'image'
                    ? 'border-purple-400 bg-purple-50 dark:bg-purple-900/20 text-purple-600 dark:text-purple-300'
                    : 'border-gray-300 dark:border-gray-600 text-gray-700 dark:text-gray-300'
                }`}
              >
                <Upload size={18} />
                <span className="text-sm">Image</span>
              </button>
            </div>

            {/* Emoji Input */}
            {avatarType === 'emoji' && (
              <div className="w-full">
                <input
                  type="text"
                  value={avatar}
                  onChange={(e) => setAvatar(e.target.value)}
                  className="w-full px-3 py-2 text-center border border-gray-300 dark:border-gray-600 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-400 bg-white dark:bg-gray-700 text-gray-900 dark:text-white text-2xl"
                  placeholder="👤"
                  maxLength={4}
                />
                <p className="text-xs text-gray-500 dark:text-gray-400 mt-1 text-center">Enter an emoji</p>
              </div>
            )}

            {/* Image Upload */}
            {avatarType === 'image' && (
              <div className="w-full">
                <label className="w-full flex flex-col items-center px-4 py-6 bg-white dark:bg-gray-700 text-gray-700 dark:text-gray-300 rounded-lg border-2 border-dashed border-gray-300 dark:border-gray-600 cursor-pointer hover:bg-gray-50 dark:hover:bg-gray-600 transition-colors">
                  <Upload size={32} className="mb-2" />
                  <span className="text-sm">Click to upload image</span>
                  <input
                    type="file"
                    className="hidden"
                    accept="image/*"
                    onChange={handleImageUpload}
                  />
                </label>
                <p className="text-xs text-gray-500 dark:text-gray-400 mt-1 text-center">PNG, JPG up to 5MB</p>
              </div>
            )}
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Name</label>
            <input
              type="text"
              value={name}
              onChange={(e) => setName(e.target.value)}
              className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:outline-none focus:ring-2 bg-white dark:bg-gray-700 text-gray-900 dark:text-white"
              onFocus={(e) => {
                e.currentTarget.style.borderColor = '#C5A8E8';
                e.currentTarget.style.boxShadow = '0 0 0 2px rgba(0, 128, 128, 0.2)';
              }}
              onBlur={(e) => {
                e.currentTarget.style.borderColor = '';
                e.currentTarget.style.boxShadow = '';
              }}
              required
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Email</label>
            <input
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:outline-none focus:ring-2 bg-white dark:bg-gray-700 text-gray-900 dark:text-white"
              onFocus={(e) => {
                e.currentTarget.style.borderColor = '#C5A8E8';
                e.currentTarget.style.boxShadow = '0 0 0 2px rgba(0, 128, 128, 0.2)';
              }}
              onBlur={(e) => {
                e.currentTarget.style.borderColor = '';
                e.currentTarget.style.boxShadow = '';
              }}
              required
            />
          </div>

          <div className="flex gap-3 pt-2">
            <button
              type="button"
              onClick={onClose}
              className="flex-1 px-4 py-3 rounded-full font-semibold transition-all hover:scale-105"
              style={{
                backgroundColor: '#F5F0FF',
                color: '#6B7280'
              }}
            >
              Cancel
            </button>
            <button
              type="submit"
              className="flex-1 px-4 py-3 text-white rounded-full font-semibold transition-all hover:scale-105 shadow-lg"
              style={{
                backgroundColor: '#7C34ED'
              }}
            >
              Save Changes
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
