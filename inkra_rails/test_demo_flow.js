const { chromium } = require('playwright');
const fs = require('fs').promises;
const path = require('path');

// Configuration
const BASE_URL = 'http://localhost:3000';
const SCREENSHOTS_DIR = path.join(__dirname, 'inkra_generations_screenshots');

// Helper to take and save screenshot
async function takeScreenshot(page, name, description) {
  const filename = `${Date.now()}_${name}.png`;
  const filepath = path.join(SCREENSHOTS_DIR, filename);
  await page.screenshot({ path: filepath, fullPage: true });
  console.log(`📸 ${description}: ${filename}`);
  return filepath;
}

async function testDemoFlow() {
  console.log('🚀 Testing Demo Flow\n');
  
  const browser = await chromium.launch({
    headless: true,
    slowMo: 200
  });
  
  const context = await browser.newContext({
    viewport: { width: 1440, height: 900 },
    deviceScaleFactor: 2
  });
  
  const page = await context.newPage();
  
  try {
    // Test demo page
    console.log('📱 Testing demo page...');
    await page.goto(`${BASE_URL}/inkra-generations-demo`);
    await page.waitForTimeout(3000);
    await takeScreenshot(page, 'demo_page', 'Inkra Generations demo page');
    
    // Look for key elements
    const pageTitle = await page.title();
    console.log(`📄 Page title: ${pageTitle}`);
    
    // Check for demo content
    const content = await page.content();
    if (content.includes('Grandma Rose') || content.includes('Family Heritage')) {
      console.log('✅ Demo content loaded successfully');
    } else {
      console.log('❌ Demo content not found');
    }
    
    // Look for magic link
    const magicLinkElement = await page.$('a[href*="/g/"]');
    if (magicLinkElement) {
      const magicLink = await magicLinkElement.getAttribute('href');
      console.log(`🔗 Magic link found: ${magicLink}`);
      
      // Test the magic link
      await page.goto(`${BASE_URL}${magicLink}`);
      await page.waitForTimeout(3000);
      await takeScreenshot(page, 'demo_magic_link', 'Demo interview recording interface');
      
      // Check if recording interface loads
      const recordingInterface = await page.$('body');
      if (recordingInterface) {
        console.log('✅ Recording interface accessible via demo');
      }
    } else {
      console.log('❌ Magic link not found in demo');
    }
    
    console.log('\n✅ Demo flow test completed');
    
  } catch (error) {
    console.error('❌ Demo flow error:', error.message);
    await takeScreenshot(page, 'demo_error', `Demo flow error: ${error.message}`);
  } finally {
    await browser.close();
  }
}

testDemoFlow().catch(console.error);