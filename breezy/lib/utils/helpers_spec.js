import {
  isGraft,
  extractNodeAndPath,
  parseSJR,
  pagePath,
  forEachJointInPage,
  forEachJointAtNameAcrossAllPages,
} from './helpers'

describe('pagePath', () => {
  it('returns the full keypath relative to the breezy store', () => {
    const path = pagePath('/foo', 'a.b.c')
    expect(path).toBe('/foo.data.a.b.c')
  })
})

describe('forEachJointAcrossAllPages', () => {
  it('iterates through each named joint across all pages', () => {
    const pages = {
      '/foo': {
        joints: {
          'header': ['a.b.c', 'd.e.f']
        }
      },
      '/bar': {
        joints: {
          'header': ['g.h.i', 'j.k.l'],
          'footer': ['g.h.i', 'j.k.l']
        }
      }
    }

    const iters = []
    forEachJointAtNameAcrossAllPages(pages, 'header', (pageKey, page, pathToJoint)=>{
      iters.push([pageKey, page, pathToJoint])
    })

    expect(iters).toEqual([
      ['/foo', pages['/foo'], 'data.a.b.c'],
      ['/foo', pages['/foo'], 'data.d.e.f'],
      ['/bar', pages['/bar'], 'data.g.h.i'],
      ['/bar', pages['/bar'], 'data.j.k.l'],
    ])
  })
})

describe('forEachJointInPage', () => {
  it('iterates through each joint in the current pages', () => {
    const page = {
      joints: {
        'header': ['g.h.i', 'j.k.l'],
        'footer': ['m.n.o', 'q.r.s']
      }
    }

    const iters = []
    forEachJointInPage(page, (jointName, jointPath)=>{
      iters.push([jointName, jointPath])
    })

    expect(iters).toEqual([
      ['header', 'data.g.h.i'],
      ['header', 'data.j.k.l'],
      ['footer', 'data.m.n.o'],
      ['footer', 'data.q.r.s'],
    ])
  })
})

describe('isGraft', () => {
  it('returns true if page is a graft', () => {
    const page = {
      action: 'graft'
    }
    expect(isGraft(page)).toBe(true)
  })

  it('returns true if page is a graft', () => {
    const page = {
    }
    expect(isGraft(page)).toBe(false)
  })
})

describe('extractNodeAndPath', () => {
  it('returns the node and the keypath to it', () => {
    const page = {
      action: 'graft',
      data: 'this is a node',
      path: 'path.to.node'
    }

    expect(extractNodeAndPath(page)).toEqual({
      node: 'this is a node',
      pathToNode: 'path.to.node'
    })
  })

  it('errors out if action is anything else', () => {
    const page = {
      data: 'this is a node',
      path: 'path.to.node'
    }

    expect(() => {
      extractNodeAndPath(page)
    }).toThrow(new Error("Expected page to be a graft response rendered from node filtering."))
  })
})