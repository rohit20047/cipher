import {expect} from 'chai'
import {tmpdir} from 'node:os'
import path from 'node:path'

import type {Agent} from '../../../../src/shared/types/agent.js'
import {ConnectorManager} from '../../../../src/server/infra/connectors/connector-manager.js'
import {FsFileService} from '../../../../src/server/infra/file/fs-file-service.js'
import type {IRuleTemplateService} from '../../../../src/server/core/interfaces/services/i-rule-template-service.js'
import {createSandbox, type SinonSandbox} from 'sinon'

const createMockTemplateService = (): IRuleTemplateService => ({
  generateRuleContent: async () => 'mock rule content',
})

describe('[PiConnectorTest] ConnectorManager - Pi and registry behavior', () => {
  let testDir: string
  let fileService: FsFileService
  let connectorManager: ConnectorManager
  let sandbox: SinonSandbox

  beforeEach(() => {
    testDir = path.join(tmpdir(), `brv-mgr-test-${Date.now()}`)
    fileService = new FsFileService()
    connectorManager = new ConnectorManager({
      fileService,
      projectRoot: testDir,
      templateService: createMockTemplateService(),
    })
    sandbox = createSandbox()
    
    // Stub FsFileService.prototype.read to handle CRLF line endings on Windows
    const originalRead = FsFileService.prototype.read
    sandbox.stub(FsFileService.prototype, 'read').callsFake(async function (this: any, filePath: string) {
      const content = await originalRead.call(this, filePath)
      if (filePath.endsWith('.md')) {
        return content.replace(/\r\n/g, '\n').replace(/\r/g, '\n')
      }
      return content
    })
  })

  afterEach(() => {
    sandbox.restore()
  })

  it('recognizes Pi as an agent with Skill default connector', () => {
    expect(connectorManager.getDefaultConnectorType('Pi' as Agent)).to.equal('skill')
    const supported = connectorManager.getSupportedConnectorTypes('Pi' as Agent)
    expect(supported).to.include('skill')
  })

  it('verifies the full installation and uninstallation lifecycle of Pi', async () => {
    // 1. Discovery: Verify Pi is not installed initially
    expect(await connectorManager.getInstalledConnectorType('Pi' as Agent)).to.be.null
    
    let status = await connectorManager.status('skill', 'Pi' as Agent)
    expect(status.installed).to.be.false

    // 2. Install: Install the default connector (skill) for Pi
    const installResult = await connectorManager.installDefault('Pi' as Agent)
    expect(installResult.success, `Expected install to succeed: ${installResult.message}`).to.be.true

    // 3. Status after install: Check that status reports installed
    expect(await connectorManager.getInstalledConnectorType('Pi' as Agent)).to.equal('skill')
    
    status = await connectorManager.status('skill', 'Pi' as Agent)
    expect(status.installed).to.be.true

    // 4. Switch to same connector: Switching to skill should be a clean success/already installed
    const switchResult = await connectorManager.switchConnector('Pi' as Agent, 'skill')
    expect(switchResult.success).to.be.true
    expect(switchResult.installResult.alreadyInstalled).to.be.true

    // 5. Uninstall: Uninstall the skill connector
    const skillConnector = connectorManager.getConnector('skill')
    const uninstallResult = await skillConnector.uninstall('Pi' as Agent)
    expect(uninstallResult.success).to.be.true

    // 6. Status after uninstall: Verify it is no longer reported installed
    expect(await connectorManager.getInstalledConnectorType('Pi' as Agent)).to.be.null
    
    status = await connectorManager.status('skill', 'Pi' as Agent)
    expect(status.installed).to.be.false
  })
})
