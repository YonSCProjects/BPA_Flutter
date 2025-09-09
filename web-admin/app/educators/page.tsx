'use client';

import { useState, useEffect } from 'react';
import { collection, getDocs, addDoc, updateDoc, deleteDoc, doc } from 'firebase/firestore';
import { db } from '@/lib/firebase-config';
import { toast } from 'sonner';
import { Pencil, Trash2, Plus, Search } from 'lucide-react';
import ProtectedRoute from '@/components/ProtectedRoute';
import DashboardLayout from '@/components/DashboardLayout';

interface Educator {
  id: string;
  name: string;
  email: string;
  classes?: string[] | string; // Can be array or string from Firestore
  active?: boolean;
  spreadsheetId?: string;
  createdAt?: Date;
  updatedAt?: Date;
}

export default function EducatorsPage() {
  const [educators, setEducators] = useState<Educator[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [showModal, setShowModal] = useState(false);
  const [editingEducator, setEditingEducator] = useState<Educator | null>(null);
  const [formData, setFormData] = useState({
    name: '',
    email: '',
    classes: '',
    spreadsheetId: '',
    active: true
  });

  useEffect(() => {
    fetchEducators();
  }, []);

  const fetchEducators = async () => {
    try {
      const querySnapshot = await getDocs(collection(db, 'educators'));
      const educatorsData: Educator[] = [];
      querySnapshot.forEach((doc) => {
        educatorsData.push({ id: doc.id, ...doc.data() } as Educator);
      });
      setEducators(educatorsData);
    } catch (error) {
      toast.error('Failed to fetch educators');
    } finally {
      setLoading(false);
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      const educatorData = {
        name: formData.name,
        email: formData.email,
        classes: formData.classes.split(',').map(c => c.trim()).filter(c => c),
        spreadsheetId: formData.spreadsheetId || null,
        active: formData.active,
        updatedAt: new Date()
      };

      if (editingEducator) {
        await updateDoc(doc(db, 'educators', editingEducator.id), educatorData);
        toast.success('Educator updated successfully');
      } else {
        await addDoc(collection(db, 'educators'), {
          ...educatorData,
          createdAt: new Date()
        });
        toast.success('Educator added successfully');
      }

      setShowModal(false);
      resetForm();
      fetchEducators();
    } catch (error) {
      toast.error('Failed to save educator');
    }
  };

  const handleDelete = async (id: string) => {
    if (window.confirm('Are you sure you want to delete this educator?')) {
      try {
        await deleteDoc(doc(db, 'educators', id));
        toast.success('Educator deleted successfully');
        fetchEducators();
      } catch (error) {
        toast.error('Failed to delete educator');
      }
    }
  };

  const handleEdit = (educator: Educator) => {
    setEditingEducator(educator);
    const classesString = Array.isArray(educator.classes) 
      ? educator.classes.join(', ') 
      : (educator.classes || '');
    setFormData({
      name: educator.name,
      email: educator.email,
      classes: classesString,
      spreadsheetId: educator.spreadsheetId || '',
      active: educator.active !== undefined ? educator.active : true
    });
    setShowModal(true);
  };

  const resetForm = () => {
    setFormData({ name: '', email: '', classes: '', spreadsheetId: '', active: true });
    setEditingEducator(null);
  };

  const filteredEducators = educators.filter(educator => {
    const searchLower = searchTerm.toLowerCase();
    const nameMatch = educator.name.toLowerCase().includes(searchLower);
    const emailMatch = educator.email.toLowerCase().includes(searchLower);
    const classesMatch = Array.isArray(educator.classes) 
      ? educator.classes.some(c => c.toLowerCase().includes(searchLower))
      : (educator.classes || '').toLowerCase().includes(searchLower);
    return nameMatch || emailMatch || classesMatch;
  });

  return (
    <ProtectedRoute>
      <DashboardLayout>
        <div>
          <div className="sm:flex sm:items-center sm:justify-between mb-8">
            <h1 className="text-2xl font-bold text-gray-900">Educators Management</h1>
            <button
              onClick={() => {
                resetForm();
                setShowModal(true);
              }}
              className="mt-3 sm:mt-0 inline-flex items-center px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700"
            >
              <Plus className="h-4 w-4 mr-2" />
              Add Educator
            </button>
          </div>

          {/* Search Bar */}
          <div className="mb-6">
            <div className="relative">
              <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-5 w-5 text-gray-400" />
              <input
                type="text"
                placeholder="Search educators..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="pl-10 pr-4 py-2 w-full border border-gray-300 rounded-md focus:ring-indigo-500 focus:border-indigo-500"
              />
            </div>
          </div>

          {/* Educators Table */}
          <div className="bg-white shadow overflow-hidden sm:rounded-lg">
            <table className="min-w-full divide-y divide-gray-200">
              <thead className="bg-gray-50">
                <tr>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Name
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Email
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Classes
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Spreadsheet ID
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Status
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Created
                  </th>
                  <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Actions
                  </th>
                </tr>
              </thead>
              <tbody className="bg-white divide-y divide-gray-200">
                {loading ? (
                  <tr>
                    <td colSpan={7} className="px-6 py-4 text-center">
                      <div className="animate-spin rounded-full h-8 w-8 border-t-2 border-b-2 border-indigo-500 mx-auto"></div>
                    </td>
                  </tr>
                ) : filteredEducators.length === 0 ? (
                  <tr>
                    <td colSpan={7} className="px-6 py-4 text-center text-gray-500">
                      No educators found
                    </td>
                  </tr>
                ) : (
                  filteredEducators.map((educator) => (
                    <tr key={educator.id}>
                      <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                        {educator.name}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                        {educator.email}
                      </td>
                      <td className="px-6 py-4 text-sm text-gray-500">
                        <div className="flex flex-wrap gap-1">
                          {Array.isArray(educator.classes) ? (
                            educator.classes.map((cls, idx) => (
                              <span key={idx} className="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-blue-100 text-blue-800">
                                {cls}
                              </span>
                            ))
                          ) : educator.classes ? (
                            <span className="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-blue-100 text-blue-800">
                              {educator.classes}
                            </span>
                          ) : (
                            <span className="text-gray-400">No classes</span>
                          )}
                        </div>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                        {educator.spreadsheetId ? (
                          <span className="text-xs font-mono">{educator.spreadsheetId.substring(0, 10)}...</span>
                        ) : (
                          <span className="text-gray-400">Not set</span>
                        )}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm">
                        <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${
                          educator.active !== false ? 'bg-green-100 text-green-800' : 'bg-gray-100 text-gray-800'
                        }`}>
                          {educator.active !== false ? 'Active' : 'Inactive'}
                        </span>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                        {educator.createdAt ? (
                          new Date((educator.createdAt as any).seconds ? (educator.createdAt as any).seconds * 1000 : educator.createdAt).toLocaleDateString()
                        ) : '-'}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                        <button
                          onClick={() => handleEdit(educator)}
                          className="text-indigo-600 hover:text-indigo-900 mr-3"
                        >
                          <Pencil className="h-4 w-4" />
                        </button>
                        <button
                          onClick={() => handleDelete(educator.id)}
                          className="text-red-600 hover:text-red-900"
                        >
                          <Trash2 className="h-4 w-4" />
                        </button>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>

          {/* Modal */}
          {showModal && (
            <div className="fixed inset-0 bg-gray-500 bg-opacity-75 flex items-center justify-center p-4 z-50">
              <div className="bg-white rounded-lg max-w-md w-full p-6">
                <h2 className="text-lg font-medium mb-4">
                  {editingEducator ? 'Edit Educator' : 'Add New Educator'}
                </h2>
                <form onSubmit={handleSubmit}>
                  <div className="space-y-4">
                    <div>
                      <label className="block text-sm font-medium text-gray-700">Name</label>
                      <input
                        type="text"
                        required
                        value={formData.name}
                        onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                        className="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm"
                      />
                    </div>
                    <div>
                      <label className="block text-sm font-medium text-gray-700">Email</label>
                      <input
                        type="email"
                        required
                        value={formData.email}
                        onChange={(e) => setFormData({ ...formData, email: e.target.value })}
                        className="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm"
                      />
                    </div>
                    <div>
                      <label className="block text-sm font-medium text-gray-700">
                        Classes (comma-separated)
                      </label>
                      <input
                        type="text"
                        required
                        value={formData.classes}
                        onChange={(e) => setFormData({ ...formData, classes: e.target.value })}
                        placeholder="Class A, Class B, Class C"
                        className="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm"
                      />
                    </div>
                    <div>
                      <label className="block text-sm font-medium text-gray-700">
                        Spreadsheet ID (optional)
                      </label>
                      <input
                        type="text"
                        value={formData.spreadsheetId}
                        onChange={(e) => setFormData({ ...formData, spreadsheetId: e.target.value })}
                        className="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm"
                      />
                    </div>
                    <div>
                      <label className="block text-sm font-medium text-gray-700">Status</label>
                      <select
                        value={formData.active ? 'active' : 'inactive'}
                        onChange={(e) => setFormData({ ...formData, active: e.target.value === 'active' })}
                        className="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm"
                      >
                        <option value="active">Active</option>
                        <option value="inactive">Inactive</option>
                      </select>
                    </div>
                  </div>
                  <div className="mt-6 flex justify-end space-x-3">
                    <button
                      type="button"
                      onClick={() => {
                        setShowModal(false);
                        resetForm();
                      }}
                      className="px-4 py-2 border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-700 bg-white hover:bg-gray-50"
                    >
                      Cancel
                    </button>
                    <button
                      type="submit"
                      className="px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700"
                    >
                      {editingEducator ? 'Update' : 'Add'}
                    </button>
                  </div>
                </form>
              </div>
            </div>
          )}
        </div>
      </DashboardLayout>
    </ProtectedRoute>
  );
}