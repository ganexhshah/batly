<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class BannerApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_admin_can_create_home_carousel_banner_with_multipart_form(): void
    {
        Storage::fake('public');
        config(['filesystems.default' => 'public']);

        $admin = User::factory()->create([
            'role' => 'Admin',
            'status' => 'Active',
        ]);

        Sanctum::actingAs($admin);

        $response = $this->post('/api/admin/home-carousel', [
            'title' => 'Test Banner',
            'prize_pool' => 'NPR 10,000',
            'date_text' => '01 JUL, 2026',
            'is_live' => '1',
            'is_active' => '1',
            'image' => UploadedFile::fake()->image('banner.jpg', 1000, 600),
        ], ['Accept' => 'application/json']);

        $response->assertCreated()
            ->assertJsonPath('banner.title', 'Test Banner');

        $this->assertDatabaseHas('banners', [
            'title' => 'Test Banner',
            'prize_pool' => 'NPR 10,000',
        ]);
    }

    public function test_home_carousel_create_requires_image_or_url(): void
    {
        $admin = User::factory()->create([
            'role' => 'Admin',
            'status' => 'Active',
        ]);

        Sanctum::actingAs($admin);

        $response = $this->postJson('/api/admin/home-carousel', [
            'title' => 'Missing Image',
            'is_live' => '0',
            'is_active' => '1',
        ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['image']);
    }

    public function test_home_carousel_accepts_string_zero_one_booleans_from_multipart(): void
    {
        Storage::fake('public');
        config(['filesystems.default' => 'public']);

        $admin = User::factory()->create([
            'role' => 'Admin',
            'status' => 'Active',
        ]);

        Sanctum::actingAs($admin);

        $response = $this->post('/api/admin/home-carousel', [
            'title' => 'Legacy Form Booleans',
            'is_live' => '0',
            'is_active' => '1',
            'image' => UploadedFile::fake()->image('banner.jpg'),
        ], ['Accept' => 'application/json']);

        $response->assertCreated()
            ->assertJsonPath('banner.isLive', false)
            ->assertJsonPath('banner.isActive', true);
    }
}
