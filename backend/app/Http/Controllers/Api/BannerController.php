<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Banner;
use App\Services\BattlyCache;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class BannerController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $includeAll = $request->boolean('all') && $request->user() !== null;

        if ($includeAll) {
            $banners = Banner::query()
                ->orderByDesc('created_at')
                ->get()
                ->map(fn (Banner $b) => $this->formatBanner($b))
                ->values()
                ->all();

            return response()->json(['banners' => $banners]);
        }

        $banners = BattlyCache::remember(
            BattlyCache::TAG_BANNERS,
            'banners:active',
            BattlyCache::TTL_BANNERS,
            fn () => Banner::query()
                ->where('is_active', true)
                ->orderByDesc('created_at')
                ->get()
                ->map(fn (Banner $b) => $this->formatBanner($b))
                ->values()
                ->all(),
        );

        return response()->json(['banners' => $banners]);
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'title' => ['required', 'string', 'max:255'],
            'prize_pool' => ['nullable', 'string', 'max:255'],
            'date_text' => ['nullable', 'string', 'max:255'],
            'is_live' => ['nullable', 'boolean'],
            'is_active' => ['nullable', 'boolean'],
            'image' => ['nullable', 'file', 'image', 'max:5120'],
            'image_url' => ['nullable', 'string', 'max:2000'],
        ]);

        $imagePath = $this->resolveImagePath($request);

        $banner = Banner::create([
            'title' => $validated['title'],
            'prize_pool' => $validated['prize_pool'] ?? null,
            'date_text' => $validated['date_text'] ?? null,
            'is_live' => $request->boolean('is_live'),
            'is_active' => $request->boolean('is_active', true),
            'image_path' => $imagePath,
        ]);

        BattlyCache::flushBanners();

        return response()->json(['banner' => $this->formatBanner($banner)], 201);
    }

    public function update(Request $request, Banner $banner): JsonResponse
    {
        $validated = $request->validate([
            'title' => ['sometimes', 'string', 'max:255'],
            'prize_pool' => ['nullable', 'string', 'max:255'],
            'date_text' => ['nullable', 'string', 'max:255'],
            'is_live' => ['nullable', 'boolean'],
            'is_active' => ['nullable', 'boolean'],
            'image' => ['nullable', 'file', 'image', 'max:5120'],
            'image_url' => ['nullable', 'string', 'max:2000'],
        ]);

        $payload = collect($validated)->except(['image', 'image_url'])->all();

        if ($request->has('is_live')) {
            $payload['is_live'] = $request->boolean('is_live');
        }
        if ($request->has('is_active')) {
            $payload['is_active'] = $request->boolean('is_active');
        }

        if ($request->hasFile('image') || $request->filled('image_url')) {
            $payload['image_path'] = $this->resolveImagePath($request);
        }

        $banner->update($payload);
        BattlyCache::flushBanners();

        return response()->json(['banner' => $this->formatBanner($banner->fresh())]);
    }

    public function destroy(Banner $banner): JsonResponse
    {
        $banner->delete();
        BattlyCache::flushBanners();

        return response()->json(['message' => 'Banner deleted']);
    }

    private function resolveImagePath(Request $request): string
    {
        if ($request->hasFile('image')) {
            $diskName = config('filesystems.default', 'public');
            $path = $request->file('image')->store('banners', $diskName);

            return Storage::disk($diskName)->url($path);
        }

        if ($request->filled('image_url')) {
            return (string) $request->input('image_url');
        }

        return 'assets/Untitled (1080 x 900 px) (1080 x 600 px).png';
    }

    private function formatBanner(Banner $banner): array
    {
        return [
            'id' => $banner->id,
            'title' => $banner->title,
            'prizePool' => $banner->prize_pool,
            'dateText' => $banner->date_text,
            'isLive' => (bool) $banner->is_live,
            'imagePath' => $banner->image_path,
            'isActive' => (bool) $banner->is_active,
        ];
    }
}
