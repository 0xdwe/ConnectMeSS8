import { X, Upload, Image as ImageIcon, FileText } from 'lucide-react';
import { useState } from 'react';
import { mockContacts } from './mock-data';

interface SharedActivityModalProps {
  onClose: () => void;
  onSave: (contactId: string, type: 'photo' | 'note', content: string) => void;
}

export function SharedActivityModal({ onClose, onSave }: SharedActivityModalProps) {
  const [selectedContact, setSelectedContact] = useState('');
  const [activityType, setActivityType] = useState<'photo' | 'note'>('note');
  const [notes, setNotes] = useState('');
  const [photoPreview, setPhotoPreview] = useState<string>('');

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      const reader = new FileReader();
      reader.onloadend = () => {
        setPhotoPreview(reader.result as string);
      };
      reader.readAsDataURL(file);
    }
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (selectedContact && (notes || photoPreview)) {
      onSave(selectedContact, activityType, activityType === 'photo' ? photoPreview : notes);
      onClose();
    }
  };

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
      <div className="bg-white dark:bg-gray-800 rounded-2xl max-w-md w-full p-6 max-h-[90vh] overflow-y-auto transition-colors">
        <div className="flex justify-between items-center mb-4">
          <h2 className="text-xl font-semibold dark:text-white">Share Activity</h2>
          <button onClick={onClose} className="p-1 hover:bg-gray-100 dark:hover:bg-gray-700 rounded-full dark:text-white">
            <X size={24} />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Contact</label>
            <select
              value={selectedContact}
              onChange={(e) => setSelectedContact(e.target.value)}
              className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:outline-none bg-white dark:bg-gray-700 text-gray-900 dark:text-white"
              onFocus={(e) => {
                e.currentTarget.style.borderColor = '#C5A8E8';
                e.currentTarget.style.boxShadow = '0 0 0 2px rgba(0, 128, 128, 0.2)';
              }}
              onBlur={(e) => {
                e.currentTarget.style.borderColor = '';
                e.currentTarget.style.boxShadow = '';
              }}
              required
            >
              <option value="">Select a contact...</option>
              {mockContacts.map(contact => (
                <option key={contact.id} value={contact.id}>
                  {contact.name}
                </option>
              ))}
            </select>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">Activity Type</label>
            <div className="grid grid-cols-2 gap-3">
              <button
                type="button"
                onClick={() => setActivityType('photo')}
                className="flex flex-col items-center gap-2 p-4 rounded-lg border-2 transition-colors dark:bg-gray-700"
                style={{
                  borderColor: activityType === 'photo' ? '#C5A8E8' : '#e5e7eb',
                  backgroundColor: activityType === 'photo' ? 'rgba(0, 128, 128, 0.15)' : undefined
                }}
              >
                <ImageIcon size={32} style={{ color: activityType === 'photo' ? '#C5A8E8' : '#737877' }} />
                <span className="text-sm font-medium dark:text-white">Photo</span>
              </button>
              <button
                type="button"
                onClick={() => setActivityType('note')}
                className="flex flex-col items-center gap-2 p-4 rounded-lg border-2 transition-colors dark:bg-gray-700"
                style={{
                  borderColor: activityType === 'note' ? '#C5A8E8' : '#e5e7eb',
                  backgroundColor: activityType === 'note' ? 'rgba(0, 128, 128, 0.15)' : undefined
                }}
              >
                <FileText size={32} style={{ color: activityType === 'note' ? '#C5A8E8' : '#737877' }} />
                <span className="text-sm font-medium dark:text-white">Note</span>
              </button>
            </div>
          </div>

          {activityType === 'photo' ? (
            <div>
              <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">Upload Photo</label>
              <label className="flex flex-col items-center justify-center w-full h-48 border-2 border-dashed rounded-lg cursor-pointer hover:bg-gray-50 transition-colors"
                style={{ borderColor: '#C5A8E8' }}>
                {photoPreview ? (
                  <img src={photoPreview} alt="Preview" className="h-full object-cover rounded-lg" />
                ) : (
                  <div className="flex flex-col items-center">
                    <Upload size={48} style={{ color: '#C5A8E8' }} />
                    <p className="mt-2 text-sm" style={{ color: '#737877' }}>
                      Click to upload photo
                    </p>
                  </div>
                )}
                <input
                  type="file"
                  className="hidden"
                  accept="image/*"
                  onChange={handleFileChange}
                />
              </label>
            </div>
          ) : (
            <div>
              <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Notes</label>
              <textarea
                value={notes}
                onChange={(e) => setNotes(e.target.value)}
                className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:outline-none bg-white dark:bg-gray-700 text-gray-900 dark:text-white"
                rows={4}
                placeholder="Describe your shared moment..."
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
          )}

          {selectedContact && (activityType === 'note' ? notes : photoPreview) && (
            <div className="bg-yellow-50 dark:bg-yellow-900/20 border border-yellow-200 dark:border-yellow-800 rounded-lg p-3">
              <div className="flex items-start gap-2">
                <span className="text-lg">💡</span>
                <div>
                  <div className="text-sm font-medium text-yellow-900 dark:text-yellow-100 mb-1">AI Suggestion</div>
                  <p className="text-sm text-yellow-800 dark:text-yellow-200">
                    This shared moment shows strong connection! Consider planning a follow-up activity within the next week to maintain momentum.
                  </p>
                </div>
              </div>
            </div>
          )}

          <div className="flex gap-3 pt-2">
            <button
              type="button"
              onClick={onClose}
              className="flex-1 px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg hover:bg-gray-50 dark:hover:bg-gray-700 transition-colors dark:text-white"
            >
              Cancel
            </button>
            <button
              type="submit"
              className="flex-1 px-4 py-2 text-white rounded-lg hover:opacity-90 transition-opacity"
              style={{ backgroundColor: '#C5A8E8' }}
            >
              Share Activity
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
