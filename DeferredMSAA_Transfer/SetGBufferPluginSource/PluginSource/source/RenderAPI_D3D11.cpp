#include "RenderAPI.h"
#include "PlatformBase.h"

// Direct3D 11 implementation of RenderAPI.

#if SUPPORT_D3D11

#include <assert.h>
#include <d3d11.h>
#include "Unity/IUnityGraphicsD3D11.h"
#include <fstream>
using namespace std;

class RenderAPI_D3D11 : public RenderAPI
{
public:
	RenderAPI_D3D11();
	virtual ~RenderAPI_D3D11() { }

	virtual void ProcessDeviceEvent(UnityGfxDeviceEventType type, IUnityInterfaces* interfaces);
	virtual void Release();

	virtual bool SetGBufferColor(int _index, int _msaaFactor, void *_colorBuffer);
	virtual bool SetGBufferDepth(int _msaaFactor, void *_depthBuffer);
	virtual void SetGBufferTarget();
	virtual void CopyGBufferDepth();

private:
	void CreateResources();
	void ReleaseResources();
	DXGI_FORMAT ConvertTypelessFormat(DXGI_FORMAT _typelessFormat);

private:
	ID3D11Device* m_Device;
	ID3D11Texture2D* gBufferColor[4];
	ID3D11Texture2D* gBufferDepth;
	ID3D11RenderTargetView* gBufferColorView[4];
	ID3D11DepthStencilView* gBufferDepthView;
	ID3D11DepthStencilView* screenDepthView;
};


RenderAPI* CreateRenderAPI_D3D11()
{
	return new RenderAPI_D3D11();
}

RenderAPI_D3D11::RenderAPI_D3D11()
{
}

void RenderAPI_D3D11::ProcessDeviceEvent(UnityGfxDeviceEventType type, IUnityInterfaces* interfaces)
{
	switch (type)
	{
	case kUnityGfxDeviceEventInitialize:
	{
		IUnityGraphicsD3D11* d3d = interfaces->Get<IUnityGraphicsD3D11>();
		m_Device = d3d->GetDevice();
		CreateResources();
		break;
	}
	case kUnityGfxDeviceEventShutdown:
		ReleaseResources();
		break;
	}
}

void RenderAPI_D3D11::Release()
{
	ReleaseResources();
}

bool RenderAPI_D3D11::SetGBufferColor(int _index, int _msaaFactor, void * _colorBuffer)
{
	gBufferColor[_index] = (ID3D11Texture2D*)_colorBuffer;

	if (gBufferColor[_index] == nullptr)
	{
		return false;
	}

	D3D11_TEXTURE2D_DESC texDesc;
	gBufferColor[_index]->GetDesc(&texDesc);
	
	D3D11_RENDER_TARGET_VIEW_DESC rtvDesc;
	ZeroMemory(&rtvDesc, sizeof(rtvDesc));
	rtvDesc.Format = ConvertTypelessFormat(texDesc.Format);
	rtvDesc.ViewDimension = (_msaaFactor > 1) ? D3D11_RTV_DIMENSION_TEXTURE2DMS : D3D11_RTV_DIMENSION_TEXTURE2D;
	rtvDesc.Texture2D.MipSlice = 0;

	HRESULT rtvResult = m_Device->CreateRenderTargetView(gBufferColor[_index], &rtvDesc, &gBufferColorView[_index]);

	if (FAILED(rtvResult))
	{
		ofstream out("GBufferRTV.txt", ios::out);
		out << "Error Code:" << rtvResult << endl;
		out << "Tex format:" << texDesc.Format;
		out.close();
	}

	return SUCCEEDED(rtvResult);
}

bool RenderAPI_D3D11::SetGBufferDepth(int _msaaFactor, void * _depthBuffer)
{
	gBufferDepth = (ID3D11Texture2D*)_depthBuffer;

	if (gBufferDepth == nullptr)
	{
		return false;
	}

	D3D11_TEXTURE2D_DESC texDesc;
	gBufferDepth->GetDesc(&texDesc);

	D3D11_DEPTH_STENCIL_VIEW_DESC dsvDesc;
	ZeroMemory(&dsvDesc, sizeof(dsvDesc));
	dsvDesc.Format = ConvertTypelessFormat(texDesc.Format);
	dsvDesc.ViewDimension = (_msaaFactor > 1) ? D3D11_DSV_DIMENSION_TEXTURE2DMS : D3D11_DSV_DIMENSION_TEXTURE2D;
	dsvDesc.Texture2D.MipSlice = 0;

	HRESULT dsvResult = m_Device->CreateDepthStencilView(gBufferDepth, &dsvDesc, &gBufferDepthView);

	if (FAILED(dsvResult))
	{
		ofstream out("GBufferDSV.txt", ios::out);
		out << "Error Code:" << dsvResult << endl;
		out << "Tex format:" << texDesc.Format;
		out.close();
	}

	return SUCCEEDED(dsvResult);
}

void RenderAPI_D3D11::SetGBufferTarget()
{
	if (m_Device == nullptr)
	{
		return;
	}

	ID3D11DeviceContext *immediateContext = nullptr;
	m_Device->GetImmediateContext(&immediateContext);

	if (immediateContext == nullptr)
	{
		return;
	}

	// set gbuffer target
	FLOAT clearColor[4] = { 0,0,0,-1 };
	for (int i = 0; i < 4; i++)
	{
		immediateContext->ClearRenderTargetView(gBufferColorView[i], clearColor);
	}

	// get unity's depth buffer
	immediateContext->OMGetRenderTargets(0, NULL, &screenDepthView);

	// replace om binding with custom targets
	immediateContext->ClearDepthStencilView(gBufferDepthView, D3D11_CLEAR_DEPTH | D3D11_CLEAR_STENCIL, 0.0f, 0);
	immediateContext->OMSetRenderTargets(4, gBufferColorView, gBufferDepthView);

	immediateContext->Release();
}

void RenderAPI_D3D11::CopyGBufferDepth()
{
	if (m_Device == nullptr)
	{
		return;
	}

	ID3D11DeviceContext *immediateContext = nullptr;
	m_Device->GetImmediateContext(&immediateContext);

	if (immediateContext == nullptr)
	{
		return;
	}

	ID3D11Resource* screenDepth;
	screenDepthView->GetResource(&screenDepth);
	immediateContext->CopyResource(screenDepth, gBufferDepth);
	screenDepth->Release();

	immediateContext->Release();
}

void RenderAPI_D3D11::CreateResources()
{

}

void RenderAPI_D3D11::ReleaseResources()
{
	for (int i = 0; i < 4; i++)
	{
		SAFE_RELEASE(gBufferColorView[i]);
	}
	SAFE_RELEASE(gBufferDepthView);
	SAFE_RELEASE(screenDepthView);
}

DXGI_FORMAT RenderAPI_D3D11::ConvertTypelessFormat(DXGI_FORMAT _typelessFormat)
{
	switch (_typelessFormat)
	{
	case DXGI_FORMAT_R8G8B8A8_TYPELESS:
		return DXGI_FORMAT_R8G8B8A8_UNORM;

	case DXGI_FORMAT_R10G10B10A2_TYPELESS:
		return DXGI_FORMAT_R10G10B10A2_UNORM;

	case DXGI_FORMAT_R16G16B16A16_TYPELESS:
		return DXGI_FORMAT_R16G16B16A16_FLOAT;

	case DXGI_FORMAT_R32G8X24_TYPELESS:
		return DXGI_FORMAT_D32_FLOAT_S8X24_UINT;

	default:
		return DXGI_FORMAT_UNKNOWN;
	}
}

#endif // #if SUPPORT_D3D11
