'use client';

import { useState, useEffect } from 'react';
import { collection, getDocs, query, where } from 'firebase/firestore';
import { db } from '@/lib/firebase-config';
import MigrationConfig from '@/lib/migration-config';
import { Users, GraduationCap, UserCheck, Activity, TrendingUp, Database } from 'lucide-react';
import ProtectedRoute from '@/components/ProtectedRoute';
import DashboardLayout from '@/components/DashboardLayout';
import Link from 'next/link';
import { useAuth } from '@/contexts/AuthContext';

interface Stats {
  users: number;
  educators: number;
  students: number;
  classes: number;
}

export default function HomePage() {
  const { user } = useAuth();
  const [stats, setStats] = useState<Stats>({
    users: 0,
    educators: 0,
    students: 0,
    classes: 0
  });
  const [loading, setLoading] = useState(true);
  const [recentActivity, setRecentActivity] = useState<any[]>([]);

  useEffect(() => {
    if (user) {
      console.log('User authenticated:', user.email);
      fetchStats();
    } else {
      console.log('No authenticated user, skipping data fetch');
      setLoading(false);
    }
  }, [user]);

  const fetchStats = async () => {
    try {
      console.log('Fetching stats from Firebase...');
      console.log('Firebase project:', 'bpapp-firebase-485c1');
      
      // Fetch users count
      const usersSnapshot = await getDocs(collection(db, 'users'));
      const usersCount = usersSnapshot.size;
      console.log('Users count:', usersCount);

      // Fetch educators count
      let educatorsCount = 0;
      if (MigrationConfig.useLegacyEducatorsCollection) {
        const educatorsSnapshot = await getDocs(collection(db, 'educators'));
        educatorsCount = educatorsSnapshot.size;
      } else {
        const educatorsQuery = query(
          collection(db, 'users'),
          where('role', '==', 'educator')
        );
        const educatorsSnapshot = await getDocs(educatorsQuery);
        educatorsCount = educatorsSnapshot.size;
      }
      console.log('Educators count:', educatorsCount);

      // Fetch students count and classes
      const studentsSnapshot = await getDocs(collection(db, 'students'));
      const studentsCount = studentsSnapshot.size;
      console.log('Students count:', studentsCount);
      
      const classesSet = new Set<string>();
      studentsSnapshot.forEach((doc) => {
        const student = doc.data();
        if (student.class) {
          classesSet.add(student.class);
        }
      });

      setStats({
        users: usersCount,
        educators: educatorsCount,
        students: studentsCount,
        classes: classesSet.size
      });

      // Get recent activity (last 5 students added)
      const recentStudents: any[] = [];
      studentsSnapshot.forEach((doc) => {
        const data = doc.data();
        if (data.createdAt) {
          recentStudents.push({
            id: doc.id,
            type: 'student',
            name: data.name,
            class: data.class,
            createdAt: data.createdAt
          });
        }
      });
      
      recentStudents.sort((a, b) => {
        const dateA = a.createdAt?.toDate?.() || new Date(0);
        const dateB = b.createdAt?.toDate?.() || new Date(0);
        return dateB.getTime() - dateA.getTime();
      });
      
      setRecentActivity(recentStudents.slice(0, 5));
    } catch (error: any) {
      console.error('Failed to fetch stats:', error);
      console.error('Error details:', error.message);
      console.error('Error code:', error.code);
    } finally {
      setLoading(false);
    }
  };

  const statCards = [
    {
      title: 'Total Users',
      value: stats.users,
      icon: UserCheck,
      color: 'bg-blue-500',
      href: '/users'
    },
    {
      title: 'Educators',
      value: stats.educators,
      icon: GraduationCap,
      color: 'bg-purple-500',
      href: '/educators'
    },
    {
      title: 'Students',
      value: stats.students,
      icon: Users,
      color: 'bg-green-500',
      href: '/students'
    },
    {
      title: 'Classes',
      value: stats.classes,
      icon: Database,
      color: 'bg-yellow-500',
      href: '/students'
    }
  ];

  return (
    <ProtectedRoute>
      <DashboardLayout>
        <div>
          <div className="mb-8">
            <h1 className="text-3xl font-bold text-gray-900">Dashboard</h1>
            <p className="mt-2 text-gray-600">Welcome to BPApp Admin Portal</p>
          </div>

          {/* Stats Grid */}
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
            {statCards.map((stat) => (
              <Link key={stat.title} href={stat.href}>
                <div className="bg-white rounded-lg shadow p-6 hover:shadow-lg transition-shadow cursor-pointer">
                  <div className="flex items-center">
                    <div className={`${stat.color} rounded-lg p-3`}>
                      <stat.icon className="h-6 w-6 text-white" />
                    </div>
                    <div className="ml-4">
                      <p className="text-sm font-medium text-gray-500">{stat.title}</p>
                      <p className="text-2xl font-bold text-gray-900">
                        {loading ? '-' : stat.value}
                      </p>
                    </div>
                  </div>
                </div>
              </Link>
            ))}
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            {/* Recent Activity */}
            <div className="bg-white rounded-lg shadow">
              <div className="px-6 py-4 border-b border-gray-200">
                <div className="flex items-center">
                  <Activity className="h-5 w-5 text-gray-500 mr-2" />
                  <h2 className="text-lg font-medium text-gray-900">Recent Activity</h2>
                </div>
              </div>
              <div className="p-6">
                {loading ? (
                  <div className="animate-spin rounded-full h-8 w-8 border-t-2 border-b-2 border-indigo-500 mx-auto"></div>
                ) : recentActivity.length === 0 ? (
                  <p className="text-gray-500 text-center">No recent activity</p>
                ) : (
                  <ul className="space-y-3">
                    {recentActivity.map((activity) => (
                      <li key={activity.id} className="flex items-center justify-between">
                        <div>
                          <p className="text-sm font-medium text-gray-900">{activity.name}</p>
                          <p className="text-xs text-gray-500">
                            Added to {activity.class}
                          </p>
                        </div>
                        <span className="text-xs text-gray-400">
                          {activity.createdAt?.toDate?.().toLocaleDateString() || 'Recently'}
                        </span>
                      </li>
                    ))}
                  </ul>
                )}
              </div>
            </div>

            {/* Quick Actions */}
            <div className="bg-white rounded-lg shadow">
              <div className="px-6 py-4 border-b border-gray-200">
                <div className="flex items-center">
                  <TrendingUp className="h-5 w-5 text-gray-500 mr-2" />
                  <h2 className="text-lg font-medium text-gray-900">Quick Actions</h2>
                </div>
              </div>
              <div className="p-6">
                <div className="space-y-3">
                  <Link href="/students">
                    <button className="w-full text-left px-4 py-3 bg-gray-50 rounded-lg hover:bg-gray-100 transition-colors">
                      <div className="flex items-center justify-between">
                        <span className="text-sm font-medium text-gray-900">Add New Student</span>
                        <Users className="h-4 w-4 text-gray-400" />
                      </div>
                    </button>
                  </Link>
                  <Link href="/educators">
                    <button className="w-full text-left px-4 py-3 bg-gray-50 rounded-lg hover:bg-gray-100 transition-colors">
                      <div className="flex items-center justify-between">
                        <span className="text-sm font-medium text-gray-900">Add New Educator</span>
                        <GraduationCap className="h-4 w-4 text-gray-400" />
                      </div>
                    </button>
                  </Link>
                  <Link href="/import">
                    <button className="w-full text-left px-4 py-3 bg-gray-50 rounded-lg hover:bg-gray-100 transition-colors">
                      <div className="flex items-center justify-between">
                        <span className="text-sm font-medium text-gray-900">Bulk Import Data</span>
                        <Database className="h-4 w-4 text-gray-400" />
                      </div>
                    </button>
                  </Link>
                </div>
              </div>
            </div>
          </div>

          {/* System Info */}
          <div className="mt-8 bg-blue-50 rounded-lg p-6">
            <h3 className="text-sm font-medium text-blue-900 mb-2">System Information</h3>
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4 text-sm text-blue-700">
              <div>
                <span className="font-medium">Firebase Project:</span> bpapp-firebase-485c1
              </div>
              <div>
                <span className="font-medium">Environment:</span> Production
              </div>
              <div>
                <span className="font-medium">Version:</span> 1.0.0
              </div>
            </div>
          </div>
        </div>
      </DashboardLayout>
    </ProtectedRoute>
  );
}