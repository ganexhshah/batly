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
        $this->prepareBannerRequest($request);

        $validated = $request->validate(
            $this->bannerValidationRules(requireImage: true),
            $this->bannerValidationMessages(),
        );

        $imagePath = $this->resolveImagePath($request);
        if ($imagePath === '') {
            return response()->json([
                'message' => 'An image file or image URL is required.',
                'errors' => ['image' => ['An image file or image URL is required.']],
            ], 422);
        }

        $banner = Banner::create([
            'title' => $validated['title'],
            'prize_pool' => $this->nullableString($validated['prize_pool'] ?? null),
            'date_text' => $this->nullableString($validated['date_text'] ?? null),
            'is_live' => $request->boolean('is_live'),
            'is_active' => $request->boolean('is_active', true),
            'image_path' => $imagePath,
        ]);

        BattlyCache::flushBanners();

        return response()->json(['banner' => $this->formatBanner($banner)], 201);
    }

    public function update(Request $request, Banner $banner): JsonResponse
    {
        $this->prepareBannerRequest($request);

        $validated = $request->validate(
            $this->bannerValidationRules(requireImage: false),
            $this->bannerValidationMessages(),
        );

        $payload = collect($validated)->except(['image', 'image_url'])->all();

        if (array_key_exists('prize_pool', $payload)) {
            $payload['prize_pool'] = $this->nullableString($payload['prize_pool']);
        }
        if (array_key_exists('date_text', $payload)) {
            $payload['date_text'] = $this->nullableString($payload['date_text']);
        }

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

    /** @return array<string, list<string>> */
    private function bannerValidationRules(bool $requireImage): array
    {
        $imageRules = ['nullable', 'file', 'mimes:jpeg,jpg,png,gif,webp', 'max:5120'];
        if ($requireImage) {
            $imageRules[] = 'required_without:image_url';
        }

        return [
            'title' => [$requireImage ? 'required' : 'sometimes', 'string', 'max:255'],
            'prize_pool' => ['nullable', 'string', 'max:255'],
            'date_text' => ['nullable', 'string', 'max:255'],
            'image' => $imageRules,
            'image_url' => array_filter([
                'nullable',
                'string',
                'max:2000',
                $requireImage ? 'required_without:image' : null,
            ]),
        ];
    }

    /** @return array<string, string> */
    private function bannerValidationMessages(): array
    {
        return [
            'title.required' => 'Banner title is required.',
            'image.required_without' => 'Upload an image file or provide an image URL.',
            'image_url.required_without' => 'Upload an image file or provide an image URL.',
            'image.mimes' => 'Banner image must be a JPEG, PNG, GIF, or WebP file.',
            'image.max' => 'Banner image must be 5 MB or smaller.',
        ];
    }

    private function nullableString(?string $value): ?string
    {
        $trimmed = trim((string) $value);

        return $trimmed === '' ? null : $trimmed;
    }

    /** Normalize multipart / camelCase banner fields before validation. */
    private function prepareBannerRequest(Request $request): void
    {
        $aliases = [
            'is_live' => 'isLive',
            'is_active' => 'isActive',
            'prize_pool' => 'prizePool',
            'date_text' => 'dateText',
            'image_url' => 'imageUrl',
        ];

        foreach ($aliases as $snake => $camel) {
            if (! $request->has($snake) && $request->has($camel)) {
                $request->merge([$snake => $request->input($camel)]);
            }
        }

        if ($request->has('is_live')) {
            $request->merge(['is_live' => $request->boolean('is_live')]);
        }

        if ($request->has('is_active')) {
            $request->merge(['is_active' => $request->boolean('is_active')]);
        }
    }

    private function resolveImagePath(Request $request): string
    {
        if ($request->hasFile('image')) {
            $diskName = config('filesystems.default', 'public');
            $path = $request->file('image')->store('banners', $diskName);

            return Storage::disk($diskName)->url($path);
        }

        if ($request->filled('image_url')) {
            return trim((string) $request->input('image_url'));
        }

        return '';
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
