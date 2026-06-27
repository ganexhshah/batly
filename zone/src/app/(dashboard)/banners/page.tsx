'use client';

import React, { useEffect, useState } from 'react';
import { useAppStore } from '@/store/useAppStore';
import { toast } from 'sonner';
import { API_BASE_URL, BACKEND_BASE_URL, apiDelete } from '@/lib/api';
import { useBanners, useInvalidateBanners, isInitialLoad } from '@/lib/admin-queries';

import { Card, CardContent } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Checkbox } from '@/components/ui/checkbox';
import { Badge } from '@/components/ui/badge';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import { 
  Plus, Trash2, Edit2, Upload, Globe, 
  Calendar, Trophy, Play, CheckCircle, Loader2, AlertCircle, Eye
} from 'lucide-react';

interface Banner {
  id: number;
  title: string;
  prizePool: string | null;
  dateText: string | null;
  isLive: boolean;
  imagePath: string;
  isActive: boolean;
}

export default function BannersPage() {
  useAppStore();
  const { data: bannersData, isPending } = useBanners();
  const invalidateBanners = useInvalidateBanners();
  const loading = isInitialLoad(isPending, bannersData);
  const banners = bannersData ?? [];
  const [viewImageUrl, setViewImageUrl] = useState<string | null>(null);
  
  // Dialog States
  const [isCreateOpen, setIsCreateOpen] = useState(false);
  const [isEditOpen, setIsEditOpen] = useState(false);
  const [isDeleteOpen, setIsDeleteOpen] = useState(false);
  
  // Selected Banner for Edit/Delete
  const [selectedBanner, setSelectedBanner] = useState<Banner | null>(null);
  
  // Form States
  const [title, setTitle] = useState('');
  const [prizePool, setPrizePool] = useState('');
  const [dateText, setDateText] = useState('');
  const [isLive, setIsLive] = useState(false);
  const [isActive, setIsActive] = useState(true);
  const [imageUrl, setImageUrl] = useState('');
  const [imageFile, setImageFile] = useState<File | null>(null);
  const [imagePreviewUrl, setImagePreviewUrl] = useState<string | null>(null);
  
  // Upload Mode: 'file' or 'url'
  const [uploadMode, setUploadMode] = useState<'file' | 'url'>('file');
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    return () => {
      if (imagePreviewUrl) {
        URL.revokeObjectURL(imagePreviewUrl);
      }
    };
  }, [imagePreviewUrl]);

  const getErrorMessage = (error: unknown) => {
    if (error instanceof Error) {
      return error.message;
    }

    return 'Something went wrong';
  };

  const handleOpenCreate = () => {
    setTitle('');
    setPrizePool('');
    setDateText('');
    setIsLive(false);
    setIsActive(true);
    setImageUrl('');
    setImageFile(null);
    resetSelectedImage();
    setUploadMode('file');
    setIsCreateOpen(true);
  };

  const handleCreateBanner = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!title.trim()) return toast.error('Title is required');
    if (uploadMode === 'file' && !imageFile) return toast.error('Please select an image file to upload');
    if (uploadMode === 'url' && !imageUrl.trim()) return toast.error('Please enter an image URL');

    try {
      setSubmitting(true);
      const formData = new FormData();
      formData.append('title', title);
      formData.append('prize_pool', prizePool);
      formData.append('date_text', dateText);
      formData.append('is_live', String(isLive));
      formData.append('is_active', String(isActive));

      if (uploadMode === 'file' && imageFile) {
        formData.append('image', imageFile);
      } else if (uploadMode === 'url') {
        formData.append('image_url', imageUrl);
      }

      await sendMultipartRequest(`${API_BASE_URL}/banners`, 'POST', formData);
      toast.success('Banner created successfully');
      setIsCreateOpen(false);
      invalidateBanners();
    } catch (error: unknown) {
      toast.error('Failed to create banner: ' + getErrorMessage(error));
    } finally {
      setSubmitting(false);
    }
  };

  const handleOpenEdit = (banner: Banner) => {
    setSelectedBanner(banner);
    setTitle(banner.title);
    setPrizePool(banner.prizePool || '');
    setDateText(banner.dateText || '');
    setIsLive(banner.isLive);
    setIsActive(banner.isActive);
    
    if (isManagedBannerImage(banner.imagePath)) {
      setUploadMode('file');
      setImageUrl('');
    } else {
      setUploadMode('url');
      setImageUrl(banner.imagePath);
    }
    
    setImageFile(null);
    setImagePreviewUrl(null);
    setIsEditOpen(true);
  };

  const handleOpenDelete = (banner: Banner) => {
    setSelectedBanner(banner);
    setIsDeleteOpen(true);
  };

  // Helper to send multipart/form-data requests manually
  const sendMultipartRequest = async (url: string, method: 'POST', formData: FormData) => {
    const token = typeof window !== 'undefined' ? localStorage.getItem('battly_token') : null;
    const response = await fetch(url, {
      method,
      headers: {
        'Accept': 'application/json',
        ...(token ? { 'Authorization': `Bearer ${token}` } : {}),
      },
      body: formData,
    });

    if (!response.ok) {
      const errData = await response.json().catch(() => ({}));
      throw new Error(errData.message || `API Error: ${response.status}`);
    }
    return response.json();
  };

  const isManagedBannerImage = (path: string) => {
    const normalizedPath = path.trim().toLowerCase();

    return (
      normalizedPath.startsWith('storage/') ||
      normalizedPath.includes(`${BACKEND_BASE_URL.toLowerCase()}/storage/`) ||
      normalizedPath.includes('localhost/storage/') ||
      normalizedPath.includes('cdn.ganeshshah.com/') ||
      normalizedPath.includes('.r2.dev/')
    );
  };

  const resetSelectedImage = () => {
    setImageFile(null);

    if (imagePreviewUrl) {
      URL.revokeObjectURL(imagePreviewUrl);
    }
    setImagePreviewUrl(null);
  };

  const handleImageFileChange = (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    event.target.value = '';

    if (!file) {
      return;
    }

    if (imagePreviewUrl) {
      URL.revokeObjectURL(imagePreviewUrl);
    }

    setImageFile(file);
    setImagePreviewUrl(URL.createObjectURL(file));
  };

  const handleUpdateBanner = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedBanner) return;
    if (!title.trim()) return toast.error('Title is required');
    if (uploadMode === 'url' && !imageUrl.trim()) return toast.error('Please enter an image URL');

    try {
      setSubmitting(true);
      const formData = new FormData();
      formData.append('title', title);
      formData.append('prize_pool', prizePool);
      formData.append('date_text', dateText);
      formData.append('is_live', String(isLive));
      formData.append('is_active', String(isActive));

      if (uploadMode === 'file' && imageFile) {
        formData.append('image', imageFile);
      } else if (uploadMode === 'url') {
        formData.append('image_url', imageUrl);
      }

      // PHP's PUT request does not parse multipart/form-data natively, so we POST to a custom endpoint
      await sendMultipartRequest(`${API_BASE_URL}/banners/${selectedBanner.id}`, 'POST', formData);
      toast.success('Banner updated successfully');
      setIsEditOpen(false);
      invalidateBanners();
    } catch (error: unknown) {
      toast.error('Failed to update banner: ' + getErrorMessage(error));
    } finally {
      setSubmitting(false);
    }
  };

  const handleDeleteBanner = async () => {
    if (!selectedBanner) return;
    try {
      setSubmitting(true);
      await apiDelete(`/banners/${selectedBanner.id}`);
      toast.success('Banner deleted successfully');
      setIsDeleteOpen(false);
      invalidateBanners();
    } catch (error: unknown) {
      toast.error('Failed to delete banner: ' + getErrorMessage(error));
    } finally {
      setSubmitting(false);
    }
  };

  // Helper to format the image preview URL
  const getPreviewUrl = (path: string) => {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    if (path.startsWith('assets/')) {
      // Direct local asset reference, return placeholder or direct asset image
      return 'https://images.unsplash.com/photo-1542751371-adc38448a05e?q=80&w=600&auto=format&fit=crop';
    }
    return `${BACKEND_BASE_URL}/${path}`;
  };

  return (
    <div className="p-6 space-y-6">
      {/* Header Section */}
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
        <div>
          <h1 className="text-2xl font-black tracking-tight text-[#FF6B00]">Home Screen Banners</h1>
          <p className="text-xs text-zinc-500 dark:text-zinc-400">
            Manage banner images and details shown in the mobile application carousel.
          </p>
        </div>
        <Button 
          onClick={handleOpenCreate} 
          className="bg-[#FF6B00] hover:bg-[#E05E00] text-white font-bold text-xs px-4 py-2.5 rounded-xl flex items-center gap-2 shadow-lg shadow-orange-500/10 transition-all active:scale-95"
        >
          <Plus className="w-4 h-4" />
          Add New Banner
        </Button>
      </div>

      {/* Main Content Area */}
      {loading ? (
        <div className="flex flex-col items-center justify-center py-20 gap-3">
          <Loader2 className="w-8 h-8 text-[#FF6B00] animate-spin" />
          <p className="text-xs font-semibold text-zinc-500">Loading banners...</p>
        </div>
      ) : banners.length === 0 ? (
        <div className="border-2 border-dashed border-zinc-200 dark:border-zinc-800 rounded-2xl p-12 text-center flex flex-col items-center justify-center gap-3">
          <AlertCircle className="w-10 h-10 text-zinc-400" />
          <h3 className="font-bold text-sm text-zinc-700 dark:text-zinc-300">No banners found</h3>
          <p className="text-xs text-zinc-500 max-w-sm">
            Create your first home screen banner to start showcasing tournaments or promotions in the app.
          </p>
          <Button 
            onClick={handleOpenCreate}
            variant="outline"
            className="mt-2 text-[#FF6B00] border-zinc-200 dark:border-zinc-800 hover:bg-zinc-50 dark:hover:bg-zinc-800/40 font-bold text-xs"
          >
            Create Banner
          </Button>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-6">
          {banners.map((banner) => (
            <Card 
              key={banner.id} 
              className={`overflow-hidden border border-zinc-200 dark:border-zinc-800 bg-white dark:bg-[#161920] rounded-2xl group transition-all duration-300 hover:shadow-xl hover:-translate-y-1 ${
                !banner.isActive && 'opacity-70'
              }`}
            >
              {/* Banner Image Preview */}
              <div 
                onClick={() => setViewImageUrl(getPreviewUrl(banner.imagePath))}
                className="relative aspect-[1000/600] w-full bg-zinc-950 overflow-hidden cursor-pointer group/img"
              >
                <img 
                  src={getPreviewUrl(banner.imagePath)} 
                  alt={banner.title} 
                  className="w-full h-full object-cover object-center group-hover:scale-105 transition-transform duration-500"
                  onError={(e) => {
                    // Fallback image on load error
                    e.currentTarget.src = 'https://images.unsplash.com/photo-1542751371-adc38448a05e?q=80&w=600&auto=format&fit=crop';
                  }}
                />
                
                {/* Overlay Badges */}
                <div className="absolute top-3 left-3 flex flex-wrap gap-2 z-10">
                  {banner.isActive ? (
                    <Badge className="bg-emerald-500/10 text-emerald-500 border-none font-bold text-[10px] px-2 py-0.5 rounded-md">
                      <CheckCircle className="w-3 h-3 mr-1 inline-block" /> Active
                    </Badge>
                  ) : (
                    <Badge className="bg-zinc-500/10 text-zinc-400 border-none font-bold text-[10px] px-2 py-0.5 rounded-md">
                      Inactive
                    </Badge>
                  )}
                  {banner.isLive && (
                    <Badge className="bg-red-500/10 text-red-500 border-none font-bold text-[10px] px-2 py-0.5 rounded-md animate-pulse">
                      <Play className="w-2.5 h-2.5 mr-1 inline-block fill-red-500" /> LIVE
                    </Badge>
                  )}
                </div>

                {/* Direct Edit/Delete floating hover menu */}
                <div className="absolute inset-0 bg-black/40 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center gap-3 z-20">
                  <Button 
                    onClick={(e) => {
                      e.stopPropagation();
                      setViewImageUrl(getPreviewUrl(banner.imagePath));
                    }}
                    size="icon" 
                    className="bg-white hover:bg-orange-50 text-zinc-900 hover:text-[#FF6B00] rounded-xl h-10 w-10 border border-zinc-100 shadow-md transition-all active:scale-95 animate-fade-in"
                    title="View Image"
                  >
                    <Eye className="w-4 h-4" />
                  </Button>
                  <Button 
                    onClick={(e) => {
                      e.stopPropagation();
                      handleOpenEdit(banner);
                    }}
                    size="icon" 
                    className="bg-white hover:bg-[#FFF6F0] text-zinc-900 hover:text-[#FF6B00] rounded-xl h-10 w-10 border border-zinc-100 shadow-md transition-all active:scale-95 animate-fade-in"
                    title="Edit Banner"
                  >
                    <Edit2 className="w-4 h-4" />
                  </Button>
                  <Button 
                    onClick={(e) => {
                      e.stopPropagation();
                      handleOpenDelete(banner);
                    }}
                    size="icon" 
                    className="bg-white hover:bg-red-50 text-red-600 rounded-xl h-10 w-10 border border-zinc-100 shadow-md transition-all active:scale-95 animate-fade-in"
                    title="Delete Banner"
                  >
                    <Trash2 className="w-4 h-4" />
                  </Button>
                </div>
              </div>

              {/* Banner Details */}
              <CardContent className="p-5 space-y-4">
                <div>
                  <h3 className="font-bold text-sm text-zinc-900 dark:text-white line-clamp-2 leading-snug whitespace-pre-line">
                    {banner.title}
                  </h3>
                </div>

                <div className="flex flex-col gap-1.5 text-xs text-zinc-500 dark:text-zinc-400 border-t border-zinc-100 dark:border-zinc-800/60 pt-3">
                  {banner.prizePool && (
                    <div className="flex items-center gap-2">
                      <Trophy className="w-3.5 h-3.5 text-[#FF6B00]" />
                      <span className="font-semibold">{banner.prizePool}</span>
                    </div>
                  )}
                  {banner.dateText && (
                    <div className="flex items-center gap-2 mt-0.5">
                      <Calendar className="w-3.5 h-3.5 text-zinc-400" />
                      <span>{banner.dateText}</span>
                    </div>
                  )}
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      )}

      {/* CREATE DIALOG */}
      <Dialog open={isCreateOpen} onOpenChange={setIsCreateOpen}>
        <DialogContent className="max-w-md bg-white dark:bg-[#161920] border border-zinc-200 dark:border-zinc-800 rounded-2xl shadow-2xl">
          <DialogHeader>
            <DialogTitle className="text-base font-black tracking-tight text-[#FF6B00]">Create New Banner</DialogTitle>
            <DialogDescription className="text-xs text-zinc-500 dark:text-zinc-400">
              Configure details and upload/link the background image for the app banner.
            </DialogDescription>
          </DialogHeader>
          <form onSubmit={handleCreateBanner} className="space-y-4 py-2">
            <div className="space-y-1.5">
              <Label htmlFor="title" className="text-xs font-bold text-zinc-700 dark:text-zinc-300">Banner Title</Label>
              <Input 
                id="title" 
                value={title} 
                onChange={(e) => setTitle(e.target.value)} 
                placeholder="e.g. BATTLY\nCHAMPIONSHIP (use \n for line breaks)" 
                className="bg-zinc-50 dark:bg-[#1f222b] border-zinc-200 dark:border-zinc-800 text-xs rounded-xl h-10"
                required
              />
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div className="space-y-1.5">
                <Label htmlFor="prizePool" className="text-xs font-bold text-zinc-700 dark:text-zinc-300">Prize Pool (Optional)</Label>
                <Input 
                  id="prizePool" 
                  value={prizePool} 
                  onChange={(e) => setPrizePool(e.target.value)} 
                  placeholder="e.g. NPR 50,000" 
                  className="bg-zinc-50 dark:bg-[#1f222b] border-zinc-200 dark:border-zinc-800 text-xs rounded-xl h-10"
                />
              </div>
              <div className="space-y-1.5">
                <Label htmlFor="dateText" className="text-xs font-bold text-zinc-700 dark:text-zinc-300">Date Text (Optional)</Label>
                <Input 
                  id="dateText" 
                  value={dateText} 
                  onChange={(e) => setDateText(e.target.value)} 
                  placeholder="e.g. 25 MAY, 2026 • 7:00 PM" 
                  className="bg-zinc-50 dark:bg-[#1f222b] border-zinc-200 dark:border-zinc-800 text-xs rounded-xl h-10"
                />
              </div>
            </div>

            {/* Upload Mode Selector */}
            <div className="space-y-2 pt-1">
              <Label className="text-xs font-bold text-zinc-700 dark:text-zinc-300">Banner Image Source</Label>
              <div className="flex gap-2 p-1 bg-zinc-100 dark:bg-[#1f222b] rounded-xl">
                <button
                  type="button"
                  onClick={() => setUploadMode('file')}
                  className={`flex-1 py-1.5 text-[10px] font-bold rounded-lg flex items-center justify-center gap-1.5 transition-all ${
                    uploadMode === 'file' 
                      ? 'bg-[#FF6B00] text-white shadow-sm' 
                      : 'text-zinc-500 dark:text-zinc-400 hover:text-zinc-800 dark:hover:text-white'
                  }`}
                >
                  <Upload className="w-3.5 h-3.5" />
                  Upload Image File
                </button>
                <button
                  type="button"
                  onClick={() => setUploadMode('url')}
                  className={`flex-1 py-1.5 text-[10px] font-bold rounded-lg flex items-center justify-center gap-1.5 transition-all ${
                    uploadMode === 'url' 
                      ? 'bg-[#FF6B00] text-white shadow-sm' 
                      : 'text-zinc-500 dark:text-zinc-400 hover:text-zinc-800 dark:hover:text-white'
                  }`}
                >
                  <Globe className="w-3.5 h-3.5" />
                  External URL
                </button>
              </div>
            </div>

            {uploadMode === 'file' ? (
              <div className="space-y-1.5">
                <Label htmlFor="imageFile" className="text-xs font-bold text-zinc-700 dark:text-zinc-300">Upload Image</Label>
                <div className="border border-dashed border-zinc-200 dark:border-zinc-800 bg-zinc-50 dark:bg-[#1f222b] hover:bg-zinc-100/50 dark:hover:bg-zinc-800/20 rounded-xl p-4 transition-colors flex flex-col items-center justify-center gap-2 cursor-pointer relative">
                  <Input 
                    id="imageFile" 
                    type="file" 
                    accept="image/*"
                    onChange={handleImageFileChange}
                    className="absolute inset-0 opacity-0 cursor-pointer w-full h-full"
                  />
                  <Upload className="w-5 h-5 text-zinc-400" />
                  <span className="text-[10px] font-bold text-zinc-600 dark:text-zinc-400">
                    {imageFile ? imageFile.name : 'Click to select banner image'}
                  </span>
                  <span className="text-[9px] text-zinc-400">
                    PNG, JPG, WEBP (recommended 1000 × 600, max 2MB)
                  </span>
                </div>
                {imagePreviewUrl && (
                  <div className="overflow-hidden rounded-xl border border-zinc-200 bg-zinc-950 dark:border-zinc-800">
                    <img
                      src={imagePreviewUrl}
                      alt="Banner preview"
                      className="aspect-[1000/600] w-full object-cover"
                    />
                  </div>
                )}
              </div>
            ) : (
              <div className="space-y-1.5">
                <Label htmlFor="imageUrl" className="text-xs font-bold text-zinc-700 dark:text-zinc-300">Image URL</Label>
                <Input 
                  id="imageUrl" 
                  value={imageUrl} 
                  onChange={(e) => setImageUrl(e.target.value)} 
                  placeholder="https://example.com/banner.png" 
                  className="bg-zinc-50 dark:bg-[#1f222b] border-zinc-200 dark:border-zinc-800 text-xs rounded-xl h-10"
                  required
                />
              </div>
            )}

            {/* Checkboxes */}
            <div className="flex items-center gap-6 pt-2 border-t border-zinc-100 dark:border-zinc-800/60">
              <div className="flex items-center gap-2">
                <Checkbox 
                  id="isLive" 
                  checked={isLive} 
                  onCheckedChange={(val) => setIsLive(!!val)}
                  className="border-zinc-300 dark:border-zinc-700 data-[state=checked]:bg-[#FF6B00] data-[state=checked]:border-[#FF6B00] rounded-md h-4.5 w-4.5"
                />
                <Label htmlFor="isLive" className="text-xs font-bold text-zinc-700 dark:text-zinc-300 cursor-pointer">Is Live (Pulse badge)</Label>
              </div>
              <div className="flex items-center gap-2">
                <Checkbox 
                  id="isActive" 
                  checked={isActive} 
                  onCheckedChange={(val) => setIsActive(!!val)}
                  className="border-zinc-300 dark:border-zinc-700 data-[state=checked]:bg-[#FF6B00] data-[state=checked]:border-[#FF6B00] rounded-md h-4.5 w-4.5"
                />
                <Label htmlFor="isActive" className="text-xs font-bold text-zinc-700 dark:text-zinc-300 cursor-pointer">Is Active (Visible in app)</Label>
              </div>
            </div>

            <DialogFooter className="pt-4 border-t border-zinc-100 dark:border-zinc-800/60">
              <Button 
                type="button" 
                variant="outline" 
                onClick={() => setIsCreateOpen(false)}
                className="border-zinc-200 dark:border-zinc-800 hover:bg-zinc-50 dark:hover:bg-zinc-800/40 font-bold text-xs rounded-xl"
              >
                Cancel
              </Button>
              <Button 
                type="submit" 
                disabled={submitting}
                className="bg-[#FF6B00] hover:bg-[#E05E00] text-white font-bold text-xs rounded-xl"
              >
                {submitting ? (
                  <>
                    <Loader2 className="w-3.5 h-3.5 mr-2 animate-spin" /> Creating...
                  </>
                ) : 'Create Banner'}
              </Button>
            </DialogFooter>
          </form>
        </DialogContent>
      </Dialog>

      {/* EDIT DIALOG */}
      <Dialog open={isEditOpen} onOpenChange={setIsEditOpen}>
        <DialogContent className="max-w-md bg-white dark:bg-[#161920] border border-zinc-200 dark:border-zinc-800 rounded-2xl shadow-2xl">
          <DialogHeader>
            <DialogTitle className="text-base font-black tracking-tight text-[#FF6B00]">Edit Banner</DialogTitle>
            <DialogDescription className="text-xs text-zinc-500 dark:text-zinc-400">
              Modify banner details, status, or replace the background image.
            </DialogDescription>
          </DialogHeader>
          <form onSubmit={handleUpdateBanner} className="space-y-4 py-2">
            <div className="space-y-1.5">
              <Label htmlFor="edit-title" className="text-xs font-bold text-zinc-700 dark:text-zinc-300">Banner Title</Label>
              <Input 
                id="edit-title" 
                value={title} 
                onChange={(e) => setTitle(e.target.value)} 
                placeholder="e.g. BATTLY\nCHAMPIONSHIP" 
                className="bg-zinc-50 dark:bg-[#1f222b] border-zinc-200 dark:border-zinc-800 text-xs rounded-xl h-10"
                required
              />
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div className="space-y-1.5">
                <Label htmlFor="edit-prizePool" className="text-xs font-bold text-zinc-700 dark:text-zinc-300">Prize Pool (Optional)</Label>
                <Input 
                  id="edit-prizePool" 
                  value={prizePool} 
                  onChange={(e) => setPrizePool(e.target.value)} 
                  placeholder="e.g. NPR 50,000" 
                  className="bg-zinc-50 dark:bg-[#1f222b] border-zinc-200 dark:border-zinc-800 text-xs rounded-xl h-10"
                />
              </div>
              <div className="space-y-1.5">
                <Label htmlFor="edit-dateText" className="text-xs font-bold text-zinc-700 dark:text-zinc-300">Date Text (Optional)</Label>
                <Input 
                  id="edit-dateText" 
                  value={dateText} 
                  onChange={(e) => setDateText(e.target.value)} 
                  placeholder="e.g. 25 MAY, 2026 • 7:00 PM" 
                  className="bg-zinc-50 dark:bg-[#1f222b] border-zinc-200 dark:border-zinc-800 text-xs rounded-xl h-10"
                />
              </div>
            </div>

            {/* Upload Mode Selector */}
            <div className="space-y-2 pt-1">
              <Label className="text-xs font-bold text-zinc-700 dark:text-zinc-300">Banner Image Source</Label>
              <div className="flex gap-2 p-1 bg-zinc-100 dark:bg-[#1f222b] rounded-xl">
                <button
                  type="button"
                  onClick={() => setUploadMode('file')}
                  className={`flex-1 py-1.5 text-[10px] font-bold rounded-lg flex items-center justify-center gap-1.5 transition-all ${
                    uploadMode === 'file' 
                      ? 'bg-[#FF6B00] text-white shadow-sm' 
                      : 'text-zinc-500 dark:text-zinc-400 hover:text-zinc-800 dark:hover:text-white'
                  }`}
                >
                  <Upload className="w-3.5 h-3.5" />
                  Replace Image File
                </button>
                <button
                  type="button"
                  onClick={() => setUploadMode('url')}
                  className={`flex-1 py-1.5 text-[10px] font-bold rounded-lg flex items-center justify-center gap-1.5 transition-all ${
                    uploadMode === 'url' 
                      ? 'bg-[#FF6B00] text-white shadow-sm' 
                      : 'text-zinc-500 dark:text-zinc-400 hover:text-zinc-800 dark:hover:text-white'
                  }`}
                >
                  <Globe className="w-3.5 h-3.5" />
                  External URL
                </button>
              </div>
            </div>

            {uploadMode === 'file' ? (
              <div className="space-y-1.5">
                <Label htmlFor="edit-imageFile" className="text-xs font-bold text-zinc-700 dark:text-zinc-300">Upload New Image (Optional)</Label>
                <div className="border border-dashed border-zinc-200 dark:border-zinc-800 bg-zinc-50 dark:bg-[#1f222b] hover:bg-zinc-100/50 dark:hover:bg-zinc-800/20 rounded-xl p-4 transition-colors flex flex-col items-center justify-center gap-2 cursor-pointer relative">
                  <Input 
                    id="edit-imageFile" 
                    type="file" 
                    accept="image/*"
                    onChange={handleImageFileChange}
                    className="absolute inset-0 opacity-0 cursor-pointer w-full h-full"
                  />
                  <Upload className="w-5 h-5 text-zinc-400" />
                  <span className="text-[10px] font-bold text-zinc-600 dark:text-zinc-400">
                    {imageFile ? imageFile.name : 'Click to select replacement image'}
                  </span>
                  <span className="text-[9px] text-zinc-400">
                    PNG, JPG, WEBP (recommended 1000 × 600, max 2MB)
                  </span>
                </div>
                {imagePreviewUrl && (
                  <div className="overflow-hidden rounded-xl border border-zinc-200 bg-zinc-950 dark:border-zinc-800">
                    <img
                      src={imagePreviewUrl}
                      alt="Replacement preview"
                      className="aspect-[1000/600] w-full object-cover"
                    />
                  </div>
                )}
              </div>
            ) : (
              <div className="space-y-1.5">
                <Label htmlFor="edit-imageUrl" className="text-xs font-bold text-zinc-700 dark:text-zinc-300">Image URL</Label>
                <Input 
                  id="edit-imageUrl" 
                  value={imageUrl} 
                  onChange={(e) => setImageUrl(e.target.value)} 
                  placeholder="https://example.com/banner.png" 
                  className="bg-zinc-50 dark:bg-[#1f222b] border-zinc-200 dark:border-zinc-800 text-xs rounded-xl h-10"
                  required
                />
              </div>
            )}

            {/* Checkboxes */}
            <div className="flex items-center gap-6 pt-2 border-t border-zinc-100 dark:border-zinc-800/60">
              <div className="flex items-center gap-2">
                <Checkbox 
                  id="edit-isLive" 
                  checked={isLive} 
                  onCheckedChange={(val) => setIsLive(!!val)}
                  className="border-zinc-300 dark:border-zinc-700 data-[state=checked]:bg-[#FF6B00] data-[state=checked]:border-[#FF6B00] rounded-md h-4.5 w-4.5"
                />
                <Label htmlFor="edit-isLive" className="text-xs font-bold text-zinc-700 dark:text-zinc-300 cursor-pointer">Is Live (Pulse badge)</Label>
              </div>
              <div className="flex items-center gap-2">
                <Checkbox 
                  id="edit-isActive" 
                  checked={isActive} 
                  onCheckedChange={(val) => setIsActive(!!val)}
                  className="border-zinc-300 dark:border-zinc-700 data-[state=checked]:bg-[#FF6B00] data-[state=checked]:border-[#FF6B00] rounded-md h-4.5 w-4.5"
                />
                <Label htmlFor="edit-isActive" className="text-xs font-bold text-zinc-700 dark:text-zinc-300 cursor-pointer">Is Active (Visible in app)</Label>
              </div>
            </div>

            <DialogFooter className="pt-4 border-t border-zinc-100 dark:border-zinc-800/60">
              <Button 
                type="button" 
                variant="outline" 
                onClick={() => setIsEditOpen(false)}
                className="border-zinc-200 dark:border-zinc-800 hover:bg-zinc-50 dark:hover:bg-zinc-800/40 font-bold text-xs rounded-xl"
              >
                Cancel
              </Button>
              <Button 
                type="submit" 
                disabled={submitting}
                className="bg-[#FF6B00] hover:bg-[#E05E00] text-white font-bold text-xs rounded-xl"
              >
                {submitting ? (
                  <>
                    <Loader2 className="w-3.5 h-3.5 mr-2 animate-spin" /> Saving...
                  </>
                ) : 'Save Changes'}
              </Button>
            </DialogFooter>
          </form>
        </DialogContent>
      </Dialog>

      {/* DELETE CONFIRMATION DIALOG */}
      <Dialog open={isDeleteOpen} onOpenChange={setIsDeleteOpen}>
        <DialogContent className="max-w-sm bg-white dark:bg-[#161920] border border-zinc-200 dark:border-zinc-800 rounded-2xl shadow-2xl">
          <DialogHeader>
            <DialogTitle className="text-base font-black tracking-tight text-red-600 flex items-center gap-2">
              <Trash2 className="w-5 h-5" />
              Delete Banner
            </DialogTitle>
            <DialogDescription className="text-xs text-zinc-500 dark:text-zinc-400">
              Are you sure you want to delete this banner? This action is permanent and cannot be undone.
            </DialogDescription>
          </DialogHeader>
          <div className="py-2 flex flex-col gap-2">
            <span className="text-xs font-bold text-zinc-800 dark:text-zinc-200">
              {selectedBanner?.title}
            </span>
            <span className="text-[10px] text-zinc-400">
              Image: {selectedBanner?.imagePath}
            </span>
          </div>
          <DialogFooter className="pt-2 border-t border-zinc-100 dark:border-zinc-800/60">
            <Button 
              type="button" 
              variant="outline" 
              onClick={() => setIsDeleteOpen(false)}
              className="border-zinc-200 dark:border-zinc-800 hover:bg-zinc-50 dark:hover:bg-zinc-800/40 font-bold text-xs rounded-xl"
            >
              Cancel
            </Button>
            <Button 
              type="button" 
              onClick={handleDeleteBanner}
              disabled={submitting}
              className="bg-red-600 hover:bg-red-700 text-white font-bold text-xs rounded-xl"
            >
              {submitting ? (
                <>
                  <Loader2 className="w-3.5 h-3.5 mr-2 animate-spin" /> Deleting...
                </>
              ) : 'Delete'}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* VIEW IMAGE LIGHTBOX DIALOG */}
      <Dialog open={!!viewImageUrl} onOpenChange={(open) => !open && setViewImageUrl(null)}>
        <DialogContent className="max-w-3xl bg-zinc-950 border border-zinc-800 p-0 overflow-hidden rounded-2xl shadow-2xl">
          <div className="relative w-full aspect-[1000/600] flex items-center justify-center">
            {viewImageUrl && (
              <img 
                src={viewImageUrl} 
                alt="Banner Full Preview" 
                className="w-full h-full object-contain bg-zinc-950"
              />
            )}
          </div>
        </DialogContent>
      </Dialog>
    </div>
  );
}
