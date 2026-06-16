// Auth Types
export interface User {
  id: number;
  email: string;
  username?: string;
  full_name: string;
  first_name?: string;
  last_name?: string;
  phone: string | null;
  photo_url?: string | null;
  is_active: boolean;
  is_staff?: boolean;
  is_superuser?: boolean;
  date_joined?: string;
  last_login?: string | null;
  fcm_token?: string | null;
}

export interface AuthResponse {
  token: string;
  user: User;
}

export interface LoginCredentials {
  email: string;
  password: string;
}

export interface RegisterData {
  email: string;
  password: string;
  full_name: string;
  phone?: string;
}

// Monitoring Types
export interface Device {
  id: number;
  device_id: string;
  device_type: string;
  child: number;
  child_name?: string;
  is_active: boolean;
  last_seen: string | null;
  last_latitude: number | null;
  last_longitude: number | null;
  battery_level: number | null;
  is_in_safe_zone?: boolean;
  created_at: string;
  updated_at?: string;
}

export interface Child {
  id: number;
  tutor: number;
  tutor_name?: string;
  full_name: string;
  // Legacy fields for compatibility
  first_name?: string;
  last_name?: string;
  date_of_birth: string;
  grade?: string;
  photo_url?: string | null;
  photo: string | null;
  notes?: string;
  is_active?: boolean;
  device: Device | null;
  created_at: string;
  updated_at: string;
}

export interface SafeZone {
  id: number;
  name: string;
  description?: string;
  zone_type: 'polygon' | 'circle' | 'school' | 'home' | 'other';
  // For circles
  center_latitude?: number | null;
  center_longitude?: number | null;
  radius_meters?: number | null;
  // Legacy fields
  latitude?: number;
  longitude?: number;
  radius?: number;
  // For polygons
  polygon_points?: Array<{lat: number; lng: number}>;
  color?: string;
  is_active: boolean;
  child: number;
  child_name?: string;
  created_at: string;
  updated_at?: string;
}

export interface Location {
  id: number;
  device: number;
  latitude: number;
  longitude: number;
  accuracy: number;
  altitude: number | null;
  speed: number | null;
  heading: number | null;
  timestamp: string;
  created_at: string;
}

export interface Alert {
  id: number;
  child: number;
  child_name: string;
  safe_zone: number | null;
  safe_zone_name: string | null;
  group?: number | null;
  alert_type: 'zone_exit' | 'zone_entry' | 'low_battery' | 'device_offline' | 'exit' | 'enter';
  status?: 'pending' | 'acknowledged' | 'resolved';
  message: string;
  latitude: number | null;
  longitude: number | null;
  is_acknowledged?: boolean;
  acknowledged_at: string | null;
  resolved_at?: string | null;
  created_at: string;
}

// Group Types
export interface ChildGroup {
  id: number;
  name: string;
  description: string;
  owner: number;
  owner_name?: string;
  color: string;
  icon: string;
  is_active: boolean;
  members_count?: number;
  tutors_count?: number;
  created_at: string;
  updated_at: string;
}

export interface GroupMembership {
  id: number;
  group: number;
  group_name?: string;
  child: number;
  child_name?: string;
  added_by: number | null;
  is_active: boolean;
  joined_at: string;
}

export interface GroupTutor {
  id: number;
  group: number;
  group_name?: string;
  tutor: number;
  tutor_name?: string;
  tutor_email?: string;
  role: 'admin' | 'monitor';
  invited_by: number | null;
  is_active: boolean;
  joined_at: string;
}

export interface GroupSafeZone {
  id: number;
  group: number;
  group_name?: string;
  name: string;
  zone_type: 'polygon' | 'circle';
  center_latitude: number | null;
  center_longitude: number | null;
  radius_meters: number | null;
  polygon_points: Array<{lat: number; lng: number}>;
  color: string;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

// API Response Types
export interface PaginatedResponse<T> {
  count: number;
  next: string | null;
  previous: string | null;
  results: T[];
}

// Dashboard Stats
export interface DashboardStats {
  total_children: number;
  active_devices: number;
  total_safe_zones: number;
  pending_alerts: number;
  recent_alerts: Alert[];
  children_status: ChildStatus[];
}

export interface ChildStatus {
  child: Child;
  last_location: Location | null;
  is_in_safe_zone: boolean;
  current_zone: SafeZone | null;
}

// Manual Notification Types
export interface Notification {
  id: number;
  title: string;
  message: string;
  recipient_type: 'all' | 'tutors' | 'specific';
  recipient_type_display?: string;
  specific_user: number | null;
  specific_user_email?: string | null;
  status: 'draft' | 'sent' | 'failed';
  status_display?: string;
  sent_count: number;
  failed_count: number;
  created_by: number | null;
  created_by_name?: string | null;
  sent_at: string | null;
  created_at: string;
  updated_at: string;
}
