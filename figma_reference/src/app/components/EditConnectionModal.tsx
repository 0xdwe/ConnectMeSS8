import { X, Trash2, Upload, Smile } from 'lucide-react';
import { useState } from 'react';
import { Contact } from './mock-data';

interface EditConnectionModalProps {
  contact: Contact;
  onClose: () => void;
  onSave: (contactId: string, updates: Partial<Contact>) => void;
  onDelete: (contactId: string) => void;
  availableCategories: string[];
}

export function EditConnectionModal({ contact, onClose, onSave, onDelete, availableCategories }: EditConnectionModalProps) {
  const [name, setName] = useState(contact.name);
  const [avatar, setAvatar] = useState(contact.avatar);
  const [avatarType, setAvatarType] = useState<'emoji' | 'image'>(contact.avatar.startsWith('http') || contact.avatar.startsWith('data:') ? 'image' : 'emoji');
  const [email, setEmail] = useState(contact.email);
  const [category, setCategory] = useState(contact.category);
  const [phone, setPhone] = useState('');
  const [address, setAddress] = useState('');
  const [instagram, setInstagram] = useState('');
  const [linkedin, setLinkedin] = useState('');
  const [whatsapp, setWhatsapp] = useState('');
  const [line, setLine] = useState('');
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false);

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
    onSave(contact.id, { name, avatar, email, category });
    onClose();
  };

  const handleDelete = () => {
    onDelete(contact.id);
    onClose();
  };

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4 overflow-y-auto">
      <div className="bg-white dark:bg-gray-800 rounded-2xl max-w-md w-full p-6 my-8 transition-colors max-h-[90vh] overflow-y-auto">
        <div className="flex justify-between items-center mb-4 sticky top-0 bg-white dark:bg-gray-800 z-10 pb-2">
          <h2 className="text-xl font-semibold dark:text-white">Edit Connection</h2>
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
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Category</label>
            <select
              value={category}
              onChange={(e) => setCategory(e.target.value as Contact['category'])}
              className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:outline-none focus:ring-2 bg-white dark:bg-gray-700 text-gray-900 dark:text-white"
              onFocus={(e) => {
                e.currentTarget.style.borderColor = '#C5A8E8';
                e.currentTarget.style.boxShadow = '0 0 0 2px rgba(0, 128, 128, 0.2)';
              }}
              onBlur={(e) => {
                e.currentTarget.style.borderColor = '';
                e.currentTarget.style.boxShadow = '';
              }}
            >
              {availableCategories.map(cat => (
                <option key={cat} value={cat}>{cat}</option>
              ))}
            </select>
          </div>

          {/* Optional Contact Information */}
          <div className="border-t border-gray-200 dark:border-gray-700 pt-4">
            <h3 className="text-sm font-semibold text-gray-700 dark:text-gray-300 mb-3">Contact Information (Optional)</h3>

            <div className="space-y-3">
              <div>
                <label className="block text-sm font-medium text-gray-600 dark:text-gray-400 mb-1">Email</label>
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
                  placeholder="john@email.com"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-600 dark:text-gray-400 mb-1">Phone</label>
                <input
                  type="tel"
                  value={phone}
                  onChange={(e) => setPhone(e.target.value)}
                  className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:outline-none focus:ring-2 bg-white dark:bg-gray-700 text-gray-900 dark:text-white"
                  onFocus={(e) => {
                    e.currentTarget.style.borderColor = '#C5A8E8';
                    e.currentTarget.style.boxShadow = '0 0 0 2px rgba(0, 128, 128, 0.2)';
                  }}
                  onBlur={(e) => {
                    e.currentTarget.style.borderColor = '';
                    e.currentTarget.style.boxShadow = '';
                  }}
                  placeholder="+1 (555) 123-4567"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-600 dark:text-gray-400 mb-1">Address</label>
                <input
                  type="text"
                  value={address}
                  onChange={(e) => setAddress(e.target.value)}
                  className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:outline-none focus:ring-2 bg-white dark:bg-gray-700 text-gray-900 dark:text-white"
                  onFocus={(e) => {
                    e.currentTarget.style.borderColor = '#C5A8E8';
                    e.currentTarget.style.boxShadow = '0 0 0 2px rgba(0, 128, 128, 0.2)';
                  }}
                  onBlur={(e) => {
                    e.currentTarget.style.borderColor = '';
                    e.currentTarget.style.boxShadow = '';
                  }}
                  placeholder="123 Main St, City, State"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-600 dark:text-gray-400 mb-1">Instagram</label>
                <input
                  type="text"
                  value={instagram}
                  onChange={(e) => setInstagram(e.target.value)}
                  className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:outline-none focus:ring-2 bg-white dark:bg-gray-700 text-gray-900 dark:text-white"
                  onFocus={(e) => {
                    e.currentTarget.style.borderColor = '#C5A8E8';
                    e.currentTarget.style.boxShadow = '0 0 0 2px rgba(0, 128, 128, 0.2)';
                  }}
                  onBlur={(e) => {
                    e.currentTarget.style.borderColor = '';
                    e.currentTarget.style.boxShadow = '';
                  }}
                  placeholder="@username"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-600 dark:text-gray-400 mb-1">LinkedIn</label>
                <input
                  type="text"
                  value={linkedin}
                  onChange={(e) => setLinkedin(e.target.value)}
                  className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:outline-none focus:ring-2 bg-white dark:bg-gray-700 text-gray-900 dark:text-white"
                  onFocus={(e) => {
                    e.currentTarget.style.borderColor = '#C5A8E8';
                    e.currentTarget.style.boxShadow = '0 0 0 2px rgba(0, 128, 128, 0.2)';
                  }}
                  onBlur={(e) => {
                    e.currentTarget.style.borderColor = '';
                    e.currentTarget.style.boxShadow = '';
                  }}
                  placeholder="linkedin.com/in/username"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-600 dark:text-gray-400 mb-1">WhatsApp</label>
                <input
                  type="tel"
                  value={whatsapp}
                  onChange={(e) => setWhatsapp(e.target.value)}
                  className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:outline-none focus:ring-2 bg-white dark:bg-gray-700 text-gray-900 dark:text-white"
                  onFocus={(e) => {
                    e.currentTarget.style.borderColor = '#C5A8E8';
                    e.currentTarget.style.boxShadow = '0 0 0 2px rgba(0, 128, 128, 0.2)';
                  }}
                  onBlur={(e) => {
                    e.currentTarget.style.borderColor = '';
                    e.currentTarget.style.boxShadow = '';
                  }}
                  placeholder="+1 (555) 123-4567"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-600 dark:text-gray-400 mb-1">LINE</label>
                <input
                  type="text"
                  value={line}
                  onChange={(e) => setLine(e.target.value)}
                  className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:outline-none focus:ring-2 bg-white dark:bg-gray-700 text-gray-900 dark:text-white"
                  onFocus={(e) => {
                    e.currentTarget.style.borderColor = '#C5A8E8';
                    e.currentTarget.style.boxShadow = '0 0 0 2px rgba(0, 128, 128, 0.2)';
                  }}
                  onBlur={(e) => {
                    e.currentTarget.style.borderColor = '';
                    e.currentTarget.style.boxShadow = '';
                  }}
                  placeholder="LINE ID"
                />
              </div>
            </div>
          </div>

          {showDeleteConfirm ? (
            <div className="bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-lg p-4">
              <p className="text-sm text-red-900 dark:text-red-200 mb-3">
                Are you sure you want to delete this connection? This action cannot be undone.
              </p>
              <div className="flex gap-3">
                <button
                  type="button"
                  onClick={() => setShowDeleteConfirm(false)}
                  className="flex-1 px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg hover:bg-gray-50 dark:hover:bg-gray-700 transition-colors dark:text-white"
                >
                  Cancel
                </button>
                <button
                  type="button"
                  onClick={handleDelete}
                  className="flex-1 px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition-colors"
                >
                  Delete
                </button>
              </div>
            </div>
          ) : (
            <>
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
              <button
                type="button"
                onClick={() => setShowDeleteConfirm(true)}
                className="w-full mt-3 px-4 py-3 rounded-full border-2 font-semibold transition-all hover:scale-105 flex items-center justify-center gap-2"
                style={{
                  color: '#FF7B9C',
                  borderColor: '#FF7B9C'
                }}
              >
                <Trash2 size={18} />
                Delete Connection
              </button>
            </>
          )}
        </form>
      </div>
    </div>
  );
}
