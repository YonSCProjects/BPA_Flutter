'use client';

import { useState, useCallback } from 'react';
import { useDropzone } from 'react-dropzone';
import { collection, addDoc, writeBatch, doc } from 'firebase/firestore';
import { db } from '@/lib/firebase-config';
import { toast } from 'sonner';
import Papa from 'papaparse';
import { Upload, FileSpreadsheet, CheckCircle, XCircle, AlertCircle } from 'lucide-react';
import ProtectedRoute from '@/components/ProtectedRoute';
import DashboardLayout from '@/components/DashboardLayout';

interface ImportResult {
  success: number;
  failed: number;
  errors: string[];
}

export default function ImportPage() {
  const [selectedCollection, setSelectedCollection] = useState<'students' | 'educators' | 'users'>('students');
  const [importing, setImporting] = useState(false);
  const [previewData, setPreviewData] = useState<any[]>([]);
  const [importResult, setImportResult] = useState<ImportResult | null>(null);

  const onDrop = useCallback((acceptedFiles: File[]) => {
    const file = acceptedFiles[0];
    if (!file) return;

    Papa.parse(file, {
      header: true,
      complete: (results) => {
        setPreviewData(results.data.filter((row: any) => {
          // Filter out empty rows
          return Object.values(row).some(value => value !== '' && value !== null);
        }));
        setImportResult(null);
      },
      error: (error) => {
        toast.error(`Failed to parse file: ${error.message}`);
      }
    });
  }, []);

  const { getRootProps, getInputProps, isDragActive } = useDropzone({
    onDrop,
    accept: {
      'text/csv': ['.csv'],
      'application/vnd.ms-excel': ['.xls'],
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet': ['.xlsx']
    },
    maxFiles: 1
  });

  const validateStudentData = (row: any) => {
    const errors = [];
    if (!row.name || row.name.trim() === '') errors.push('Name is required');
    if (!row.class || row.class.trim() === '') errors.push('Class is required');
    return errors;
  };

  const validateEducatorData = (row: any) => {
    const errors = [];
    if (!row.name || row.name.trim() === '') errors.push('Name is required');
    if (!row.email || row.email.trim() === '') errors.push('Email is required');
    if (row.email && !row.email.includes('@')) errors.push('Invalid email format');
    if (!row.classes || row.classes.trim() === '') errors.push('Classes are required');
    return errors;
  };

  const validateUserData = (row: any) => {
    const errors = [];
    if (!row.email || row.email.trim() === '') errors.push('Email is required');
    if (row.email && !row.email.includes('@')) errors.push('Invalid email format');
    if (!row.role || row.role.trim() === '') errors.push('Role is required');
    return errors;
  };

  const handleImport = async () => {
    if (previewData.length === 0) {
      toast.error('No data to import');
      return;
    }

    setImporting(true);
    const result: ImportResult = {
      success: 0,
      failed: 0,
      errors: []
    };

    const batch = writeBatch(db);
    
    for (let i = 0; i < previewData.length; i++) {
      const row = previewData[i];
      let errors: string[] = [];
      let docData: any = {};

      try {
        switch (selectedCollection) {
          case 'students':
            errors = validateStudentData(row);
            if (errors.length === 0) {
              docData = {
                name: row.name.trim(),
                class: row.class.trim(),
                createdAt: new Date(),
                updatedAt: new Date()
              };
            }
            break;

          case 'educators':
            errors = validateEducatorData(row);
            if (errors.length === 0) {
              docData = {
                name: row.name.trim(),
                email: row.email.trim(),
                classes: row.classes.split(',').map((c: string) => c.trim()).filter((c: string) => c),
                spreadsheetId: row.spreadsheetId?.trim() || null,
                createdAt: new Date(),
                updatedAt: new Date()
              };
            }
            break;

          case 'users':
            errors = validateUserData(row);
            if (errors.length === 0) {
              docData = {
                email: row.email.trim(),
                role: row.role.trim(),
                name: row.name?.trim() || '',
                createdAt: new Date(),
                updatedAt: new Date()
              };
            }
            break;
        }

        if (errors.length > 0) {
          result.failed++;
          result.errors.push(`Row ${i + 1}: ${errors.join(', ')}`);
        } else {
          const docRef = doc(collection(db, selectedCollection));
          batch.set(docRef, docData);
          result.success++;
        }
      } catch (error: any) {
        result.failed++;
        result.errors.push(`Row ${i + 1}: ${error.message}`);
      }
    }

    try {
      await batch.commit();
      setImportResult(result);
      
      if (result.success > 0) {
        toast.success(`Successfully imported ${result.success} records`);
      }
      if (result.failed > 0) {
        toast.error(`Failed to import ${result.failed} records`);
      }
    } catch (error) {
      toast.error('Failed to complete import');
    } finally {
      setImporting(false);
    }
  };

  const getTemplateHeaders = () => {
    switch (selectedCollection) {
      case 'students':
        return ['name', 'class'];
      case 'educators':
        return ['name', 'email', 'classes', 'spreadsheetId'];
      case 'users':
        return ['email', 'role', 'name'];
      default:
        return [];
    }
  };

  const downloadTemplate = () => {
    const headers = getTemplateHeaders();
    const csv = Papa.unparse([headers]);
    const blob = new Blob([csv], { type: 'text/csv' });
    const url = window.URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `${selectedCollection}_template.csv`;
    a.click();
  };

  return (
    <ProtectedRoute>
      <DashboardLayout>
        <div>
          <h1 className="text-2xl font-bold text-gray-900 mb-8">Bulk Import</h1>

          {/* Collection Selector */}
          <div className="mb-6">
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Select Collection
            </label>
            <div className="flex space-x-4">
              {(['students', 'educators', 'users'] as const).map((col) => (
                <button
                  key={col}
                  onClick={() => {
                    setSelectedCollection(col);
                    setPreviewData([]);
                    setImportResult(null);
                  }}
                  className={`px-4 py-2 rounded-md text-sm font-medium capitalize ${
                    selectedCollection === col
                      ? 'bg-indigo-600 text-white'
                      : 'bg-white text-gray-700 border border-gray-300 hover:bg-gray-50'
                  }`}
                >
                  {col}
                </button>
              ))}
            </div>
          </div>

          {/* Template Download */}
          <div className="mb-6 p-4 bg-blue-50 rounded-lg">
            <div className="flex items-center justify-between">
              <div>
                <h3 className="text-sm font-medium text-blue-900">Download Template</h3>
                <p className="text-sm text-blue-700 mt-1">
                  Use our CSV template to ensure correct data format
                </p>
              </div>
              <button
                onClick={downloadTemplate}
                className="inline-flex items-center px-3 py-2 border border-transparent text-sm leading-4 font-medium rounded-md text-blue-700 bg-blue-100 hover:bg-blue-200"
              >
                <FileSpreadsheet className="h-4 w-4 mr-2" />
                Download Template
              </button>
            </div>
          </div>

          {/* File Upload */}
          <div
            {...getRootProps()}
            className={`mb-6 border-2 border-dashed rounded-lg p-8 text-center cursor-pointer transition-colors ${
              isDragActive ? 'border-indigo-500 bg-indigo-50' : 'border-gray-300 hover:border-gray-400'
            }`}
          >
            <input {...getInputProps()} />
            <Upload className="mx-auto h-12 w-12 text-gray-400" />
            <p className="mt-2 text-sm text-gray-600">
              {isDragActive
                ? 'Drop the file here...'
                : 'Drag and drop a CSV file here, or click to select'}
            </p>
            <p className="text-xs text-gray-500 mt-1">CSV files only</p>
          </div>

          {/* Preview Table */}
          {previewData.length > 0 && (
            <div className="mb-6">
              <h3 className="text-lg font-medium text-gray-900 mb-4">
                Preview ({previewData.length} rows)
              </h3>
              <div className="bg-white shadow overflow-hidden sm:rounded-lg max-h-96 overflow-y-auto">
                <table className="min-w-full divide-y divide-gray-200">
                  <thead className="bg-gray-50 sticky top-0">
                    <tr>
                      {Object.keys(previewData[0]).map((header) => (
                        <th
                          key={header}
                          className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
                        >
                          {header}
                        </th>
                      ))}
                    </tr>
                  </thead>
                  <tbody className="bg-white divide-y divide-gray-200">
                    {previewData.slice(0, 10).map((row, idx) => (
                      <tr key={idx}>
                        {Object.values(row).map((value: any, i) => (
                          <td key={i} className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                            {value || '-'}
                          </td>
                        ))}
                      </tr>
                    ))}
                  </tbody>
                </table>
                {previewData.length > 10 && (
                  <div className="bg-gray-50 px-6 py-3 text-sm text-gray-500">
                    Showing first 10 rows of {previewData.length}
                  </div>
                )}
              </div>

              <button
                onClick={handleImport}
                disabled={importing}
                className="mt-4 inline-flex items-center px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700 disabled:opacity-50"
              >
                {importing ? 'Importing...' : `Import ${previewData.length} Records`}
              </button>
            </div>
          )}

          {/* Import Results */}
          {importResult && (
            <div className="mt-6">
              <h3 className="text-lg font-medium text-gray-900 mb-4">Import Results</h3>
              <div className="grid grid-cols-2 gap-4 mb-4">
                <div className="bg-green-50 p-4 rounded-lg">
                  <div className="flex items-center">
                    <CheckCircle className="h-5 w-5 text-green-500 mr-2" />
                    <span className="text-sm font-medium text-green-900">
                      Successful: {importResult.success}
                    </span>
                  </div>
                </div>
                <div className="bg-red-50 p-4 rounded-lg">
                  <div className="flex items-center">
                    <XCircle className="h-5 w-5 text-red-500 mr-2" />
                    <span className="text-sm font-medium text-red-900">
                      Failed: {importResult.failed}
                    </span>
                  </div>
                </div>
              </div>
              
              {importResult.errors.length > 0 && (
                <div className="bg-yellow-50 p-4 rounded-lg">
                  <div className="flex items-start">
                    <AlertCircle className="h-5 w-5 text-yellow-500 mr-2 mt-0.5" />
                    <div>
                      <p className="text-sm font-medium text-yellow-900 mb-2">Errors:</p>
                      <ul className="text-sm text-yellow-700 space-y-1">
                        {importResult.errors.slice(0, 10).map((error, idx) => (
                          <li key={idx}>{error}</li>
                        ))}
                        {importResult.errors.length > 10 && (
                          <li>... and {importResult.errors.length - 10} more errors</li>
                        )}
                      </ul>
                    </div>
                  </div>
                </div>
              )}
            </div>
          )}
        </div>
      </DashboardLayout>
    </ProtectedRoute>
  );
}