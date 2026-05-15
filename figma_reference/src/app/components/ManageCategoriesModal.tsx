import { X, Plus, Edit2, Trash2, Check } from 'lucide-react';
import { useState } from 'react';

interface ManageCategoriesModalProps {
  categories: string[];
  onClose: () => void;
  onSave: (categories: string[]) => void;
}

export function ManageCategoriesModal({ categories, onClose, onSave }: ManageCategoriesModalProps) {
  const [categoryList, setCategoryList] = useState<string[]>([...categories]);
  const [newCategory, setNewCategory] = useState('');
  const [editingIndex, setEditingIndex] = useState<number | null>(null);
  const [editingValue, setEditingValue] = useState('');

  const defaultCategories = ['Family', 'Friends', 'High School', 'College', 'Work', 'Other'];

  const handleAddCategory = () => {
    if (newCategory.trim() && !categoryList.includes(newCategory.trim())) {
      setCategoryList([...categoryList, newCategory.trim()]);
      setNewCategory('');
    }
  };

  const handleEditCategory = (index: number) => {
    setEditingIndex(index);
    setEditingValue(categoryList[index]);
  };

  const handleSaveEdit = () => {
    if (editingIndex !== null && editingValue.trim() && !categoryList.includes(editingValue.trim())) {
      const updated = [...categoryList];
      updated[editingIndex] = editingValue.trim();
      setCategoryList(updated);
      setEditingIndex(null);
      setEditingValue('');
    }
  };

  const handleCancelEdit = () => {
    setEditingIndex(null);
    setEditingValue('');
  };

  const handleDeleteCategory = (index: number) => {
    const categoryToDelete = categoryList[index];
    if (defaultCategories.includes(categoryToDelete)) {
      return; // Don't allow deleting default categories
    }
    setCategoryList(categoryList.filter((_, i) => i !== index));
  };

  const handleSave = () => {
    onSave(categoryList);
    onClose();
  };

  const isDefaultCategory = (category: string) => {
    return defaultCategories.includes(category);
  };

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
      <div className="bg-white dark:bg-gray-800 rounded-2xl max-w-md w-full p-6 max-h-[80vh] overflow-y-auto transition-colors">
        <div className="flex justify-between items-center mb-4">
          <h2 className="text-xl font-semibold dark:text-white">Manage Categories</h2>
          <button onClick={onClose} className="p-1 hover:bg-gray-100 dark:hover:bg-gray-700 rounded-full dark:text-white">
            <X size={24} />
          </button>
        </div>

        <div className="mb-4 p-3 bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-800 rounded-lg">
          <p className="text-sm text-blue-900 dark:text-blue-100">
            Default categories cannot be deleted, but you can add custom ones.
          </p>
        </div>

        <div className="mb-4">
          <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
            Add New Category
          </label>
          <div className="flex gap-2">
            <input
              type="text"
              value={newCategory}
              onChange={(e) => setNewCategory(e.target.value)}
              onKeyPress={(e) => e.key === 'Enter' && handleAddCategory()}
              placeholder="e.g., Neighbors, Gym Friends..."
              className="flex-1 px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-400 bg-white dark:bg-gray-700 text-gray-900 dark:text-white"
            />
            <button
              onClick={handleAddCategory}
              disabled={!newCategory.trim()}
              className="px-4 py-2 rounded-lg text-white hover:opacity-90 transition-opacity disabled:opacity-50 disabled:cursor-not-allowed"
              style={{ backgroundColor: '#C5A8E8' }}
            >
              <Plus size={20} />
            </button>
          </div>
        </div>

        <div className="space-y-2">
          <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
            Your Categories
          </label>
          {categoryList.map((category, index) => (
            <div
              key={index}
              className="flex items-center gap-2 p-3 bg-gray-50 dark:bg-gray-700 rounded-lg border border-gray-200 dark:border-gray-600"
            >
              {editingIndex === index ? (
                <>
                  <input
                    type="text"
                    value={editingValue}
                    onChange={(e) => setEditingValue(e.target.value)}
                    onKeyPress={(e) => e.key === 'Enter' && handleSaveEdit()}
                    className="flex-1 px-2 py-1 border border-gray-300 dark:border-gray-600 rounded focus:outline-none focus:ring-2 focus:ring-purple-400 bg-white dark:bg-gray-800 text-gray-900 dark:text-white"
                    autoFocus
                  />
                  <button
                    onClick={handleSaveEdit}
                    className="p-1 text-purple-600 hover:bg-purple-50 dark:hover:bg-purple-900/20 rounded"
                  >
                    <Check size={18} />
                  </button>
                  <button
                    onClick={handleCancelEdit}
                    className="p-1 text-gray-600 dark:text-gray-400 hover:bg-gray-200 dark:hover:bg-gray-600 rounded"
                  >
                    <X size={18} />
                  </button>
                </>
              ) : (
                <>
                  <span className="flex-1 text-gray-900 dark:text-white">{category}</span>
                  {isDefaultCategory(category) && (
                    <span className="text-xs px-2 py-1 bg-gray-200 dark:bg-gray-600 text-gray-600 dark:text-gray-300 rounded-full">
                      Default
                    </span>
                  )}
                  <button
                    onClick={() => handleEditCategory(index)}
                    className="p-1 text-gray-600 dark:text-gray-400 hover:bg-gray-200 dark:hover:bg-gray-600 rounded"
                  >
                    <Edit2 size={18} />
                  </button>
                  <button
                    onClick={() => handleDeleteCategory(index)}
                    disabled={isDefaultCategory(category)}
                    className="p-1 text-red-600 dark:text-red-400 hover:bg-red-50 dark:hover:bg-red-900/20 rounded disabled:opacity-30 disabled:cursor-not-allowed"
                  >
                    <Trash2 size={18} />
                  </button>
                </>
              )}
            </div>
          ))}
        </div>

        <div className="flex gap-3 pt-4 mt-4 border-t border-gray-200 dark:border-gray-700">
          <button
            onClick={onClose}
            className="flex-1 px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg hover:bg-gray-50 dark:hover:bg-gray-700 transition-colors dark:text-white"
          >
            Cancel
          </button>
          <button
            onClick={handleSave}
            className="flex-1 px-4 py-2 text-white rounded-lg hover:opacity-90 transition-opacity"
            style={{ backgroundColor: '#C5A8E8' }}
          >
            Save Changes
          </button>
        </div>
      </div>
    </div>
  );
}
