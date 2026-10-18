/* Real Metal allocation, upload, texture alias, sampler and GPU-write checks. */
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include "../nvn_metal_resources.h"
#include "../nvn_state.h"
#include "../nvn_host.h"
#include "../nvn_tex.h"
#include "../nvn_texture_transfer.h"
#include <pthread.h>
#include <assert.h>

typedef struct { NVNtexture *texture;NVNcopyRegion region; } flush_test;
static void *flush_small_stack(void *argument) {
    flush_test *t=argument;
    ((PFNNVNTEXTUREFLUSHTEXELSPROC)(uintptr_t)nvn_lookup("nvnTextureFlushTexels"))(t->texture,NULL,&t->region);
    return NULL;
}

int main(void) {
    @autoreleasepool {
        id<MTLDevice> device=MTLCreateSystemDefaultDevice(); assert(device);
        uint8_t *memory=calloc(1,4096); assert(memory);
        uint64_t pool[8]={0},object[24]={0} /* sizeof(NVNtexture)=0xC0 */,builder[8]={0},sampler[8]={0};
        nvn_st_ent *s=nvn_st_new(pool,4 /* memory pool */); assert(s);
        s->v[1]=(uintptr_t)memory;s->v[2]=4096;s->v[3]=NVN_MEMORY_POOL_FLAGS_CPU_CACHED;
        for(int y=0;y<4;++y)for(int x=0;x<4;++x){
            uint8_t *p=memory+y*32+x*4;p[0]=17;p[1]=34;p[2]=51;p[3]=255;
        }
        nvn_resource_snapshot texture={.object=(uintptr_t)object,
            .words={0,4,4,1,1,0x25,0x10,1,1,(uintptr_t)pool,0,32,0,0,0,1}};
        id<MTLTexture> tex=nvn_metal_texture(device,&texture,NULL,0);assert(tex);
        uint8_t pixels[64]={0};
        [tex getBytes:pixels bytesPerRow:16 fromRegion:MTLRegionMake2D(0,0,4,4) mipmapLevel:0];
        for(int i=0;i<16;++i)assert(pixels[i*4]==17 && pixels[i*4+2]==51 && pixels[i*4+3]==255);
        assert(nvn_metal_texture(device,&texture,NULL,1)==tex);
        id<MTLCommandQueue> q=[device newCommandQueue];id<MTLCommandBuffer> cb=[q commandBuffer];
        MTLRenderPassDescriptor *pass=[MTLRenderPassDescriptor renderPassDescriptor];
        pass.colorAttachments[0].texture=tex;pass.colorAttachments[0].loadAction=MTLLoadActionClear;
        pass.colorAttachments[0].storeAction=MTLStoreActionStore;
        pass.colorAttachments[0].clearColor=MTLClearColorMake(1,0,0,1);
        id<MTLRenderCommandEncoder> encoder=[cb renderCommandEncoderWithDescriptor:pass];assert(encoder);
        [encoder endEncoding];[cb commit];[cb waitUntilCompleted];assert(cb.status==MTLCommandBufferStatusCompleted);
        tex=nvn_metal_texture(device,&texture,NULL,0);
        [tex getBytes:pixels bytesPerRow:16 fromRegion:MTLRegionMake2D(0,0,4,4) mipmapLevel:0];
        assert(pixels[0]==255 && pixels[1]==0 && pixels[2]==0 && pixels[3]==255);
        nvn_st_ent *tracked=nvn_st_new(object,12);assert(tracked);
        memcpy(tracked->v,texture.words,sizeof tracked->v);nvn_resources_stamp(object,12);
        uint8_t green[8]={0,255,0,255,0,255,0,255};NVNcopyRegion update={1,1,0,2,1,1};
        ((PFNNVNTEXTUREWRITETEXELSPROC)(uintptr_t)nvn_lookup("nvnTextureWriteTexels"))((NVNtexture *)object,NULL,&update,green);
        [tex getBytes:pixels bytesPerRow:16 fromRegion:MTLRegionMake2D(0,0,4,4) mipmapLevel:0];
        assert(pixels[20]==255&&pixels[21]==0); /* cached CPU data awaits flush */
        flush_test ft={(NVNtexture *)object,update};pthread_t flush_thread;pthread_attr_t attr;
        assert(!pthread_attr_init(&attr));assert(!pthread_attr_setstacksize(&attr,16384));
        assert(!pthread_create(&flush_thread,&attr,flush_small_stack,&ft));
        assert(!pthread_join(flush_thread,NULL));pthread_attr_destroy(&attr);
        assert(nvn_metal_texture(device,&texture,NULL,0)==tex);
        [tex getBytes:pixels bytesPerRow:16 fromRegion:MTLRegionMake2D(0,0,4,4) mipmapLevel:0];
        for(unsigned y=0;y<4;y++)for(unsigned x=0;x<4;x++){
            unsigned i=(y*4+x)*4;int patched=y==1&&(x==1||x==2);
            assert(pixels[i]==(patched?0:255)&&pixels[i+1]==(patched?255:0)&&pixels[i+2]==0&&pixels[i+3]==255);
        }
        nvn_fn defaults=nvn_lookup("nvnSamplerBuilderSetDefaults");
        defaults((uintptr_t)builder,0,0,0,0,0,0,0);
        assert(nvn_lookup("nvnSamplerInitialize")((uintptr_t)sampler,(uintptr_t)builder,0,0,0,0,0,0));
        nvn_resource_snapshot sampler_state;assert(nvn_resources_snapshot(sampler,8 /* sampler */,&sampler_state));
        assert(nvn_metal_sampler(device,&sampler_state));
        nvn_view_state view={.flags=NVN_VIEW_FORMAT,.format=0x38};
        id<MTLTexture> srgb=nvn_metal_texture(device,&texture,&view,0);assert(srgb);
        assert(srgb.pixelFormat==MTLPixelFormatRGBA8Unorm_sRGB);
        /* A packaged 16x65 image uses one GOB in height, whereas the automatic
         * layout chooses eight. Check uploaded pixels, not only metadata. */
        uint8_t *packed_memory=calloc(1,8192);assert(packed_memory);
        uint64_t packed_pool[8]={0},packed_object[8]={0};
        nvn_st_ent *pp=nvn_st_new(packed_pool,4);assert(pp);
        pp->v[1]=(uintptr_t)packed_memory;pp->v[2]=8192;
        for(unsigned y=0;y<65;y++)for(unsigned x=0;x<16;x++){
            uint64_t offset=nvn_tex_block_offset(x,y,16,4,0);
            packed_memory[offset]=(uint8_t)y;packed_memory[offset+1]=(uint8_t)x;
            packed_memory[offset+2]=97;packed_memory[offset+3]=255;
        }
        nvn_resource_snapshot packaged={.object=(uintptr_t)packed_object,
            .words={0,16,65,1,1,0x25,0,1,1,(uintptr_t)packed_pool,0,0,
                NVN_TEX_HAS_PACKAGE|NVN_TEX_HAS_SWIZZLE|UINT64_C(0x01020304),0,0,2}};
        id<MTLTexture> packed_tex=nvn_metal_texture(device,&packaged,NULL,1);assert(packed_tex);
        uint8_t packed_pixels[16*65*4];
        [packed_tex getBytes:packed_pixels bytesPerRow:64 fromRegion:MTLRegionMake2D(0,0,16,65) mipmapLevel:0];
        for(unsigned y=0;y<65;y++)for(unsigned x=0;x<16;x++){
            unsigned i=(y*16+x)*4;
            assert(packed_pixels[i]==y&&packed_pixels[i+1]==x&&packed_pixels[i+2]==97&&packed_pixels[i+3]==255);
        }
        id<MTLTexture> swizzled=nvn_metal_texture(device,&packaged,NULL,0);assert(swizzled);
        assert(swizzled.swizzle.red==MTLTextureSwizzleBlue&&swizzled.swizzle.alpha==MTLTextureSwizzleOne);
        nvn_view_state identity_view={.flags=NVN_VIEW_SWIZZLE,.swizzle={2,3,4,5}};
        id<MTLTexture> identity=nvn_metal_texture(device,&packaged,&identity_view,0);assert(identity);
        assert(identity.swizzle.red==MTLTextureSwizzleRed&&identity.swizzle.alpha==MTLTextureSwizzleAlpha);
        /* 3D R8 4x4x4 (game volume textures) uploads and reads back in z → y → x order. */
        {
            uint8_t *volume=calloc(1,8192);assert(volume);
            uint64_t volume_pool[8]={0},volume_object[24]={0};
            nvn_st_ent *vp=nvn_st_new(volume_pool,4);assert(vp);vp->v[1]=(uintptr_t)volume;vp->v[2]=8192;
            nvn_tex_layout vl={0};vl.width=vl.height=vl.depth=4;vl.layers=vl.mip_levels=1;vl.bytes_per_block=1;
            vl.block_w=vl.block_h=vl.samples_x=vl.samples_y=1;vl.dims=3;
            uint8_t vh=tex_adjust_tile_size(nvn_tex_default_tile_h(4,1,1),8,4),vd=tex_adjust_tile_size(tex_pick_tile_size(6),1,4);
            for(unsigned z=0;z<4;z++)for(unsigned y=0;y<4;y++)for(unsigned x=0;x<4;x++)
                volume[nvn_tex_block_offset3d(x,y,z,4,4,1,vh,vd)]=(uint8_t)(z*16+y*4+x+1);
            nvn_resource_snapshot vt={.object=(uintptr_t)volume_object,
                .words={0,4,4,4,1,1,0,2,1,(uintptr_t)volume_pool,0,0,0,0,0,9}};
            id<MTLTexture> v3=nvn_metal_texture(device,&vt,NULL,0);assert(v3&&v3.textureType==MTLTextureType3D&&v3.depth==4);
            uint8_t back[64];[v3 getBytes:back bytesPerRow:4 bytesPerImage:16 fromRegion:MTLRegionMake3D(0,0,0,4,4,4) mipmapLevel:0 slice:0];
            for(unsigned i=0;i<64;i++)assert(back[i]==i+1);
            /* A layer view of a 3D texture is invalid in Metal: must be rejected, not abort. */
            nvn_view_state slice={.flags=NVN_VIEW_LAYERS,.base_layer=0,.layer_count=1};
            assert(nvn_metal_texture(device,&vt,&slice,0)==v3||nvn_metal_texture(device,&vt,&slice,0)==nil);
            free(volume);
        }
        /* One face of a cube viewed without a target becomes a 2D view (Metal aborts on Cube with 1 slice). */
        {
            uint8_t *faces=calloc(1,65536);assert(faces);
            uint64_t cube_pool[8]={0},cube_object[24]={0};
            nvn_st_ent *cp=nvn_st_new(cube_pool,4);assert(cp);cp->v[1]=(uintptr_t)faces;cp->v[2]=65536;
            nvn_resource_snapshot ct={.object=(uintptr_t)cube_object,
                .words={0,4,4,1,1,0x25,0,8,1,(uintptr_t)cube_pool,0,0,0,0,0,11}};
            id<MTLTexture> cube=nvn_metal_texture(device,&ct,NULL,0);assert(cube&&cube.textureType==MTLTextureTypeCube);
            nvn_view_state face={.flags=NVN_VIEW_LAYERS,.base_layer=3,.layer_count=1};
            id<MTLTexture> one=nvn_metal_texture(device,&ct,&face,0);assert(one&&one.textureType==MTLTextureType2D);
            nvn_view_state bad={.flags=NVN_VIEW_LAYERS|NVN_VIEW_TARGET,.base_layer=0,.layer_count=1,.target=8};
            assert(nvn_metal_texture(device,&ct,&bad,0)==nil);
            free(faces);
        }
        texture.words[15]++;assert(nvn_metal_texture(device,&texture,NULL,0)!=tex);
        texture.words[5]=0;assert(!nvn_metal_texture(device,&texture,NULL,0));
        nvn_metal_resources_reset();nvn_st_reset();free(memory);free(packed_memory);
        puts("METAL_RESOURCES_PASS: upload, shared render/sample identity, GPU writes, views, serial reuse and default sampler");
    }
    return 0;
}
