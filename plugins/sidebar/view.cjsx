React = require('react')
ReactDOM = require('react-dom')
normalizeString = require('../../src/utils').normalizeString

module.exports=
class SidebarComponent extends React.Component
  constructor: ->
    @.props = {'links': {}}

  render: ->
    # Get links
    links = []
    for category in Object.keys(@props.links)
      # Push category title
      links.push <h4 key={category}>{category}</h4>
      for link in @props.links[category]
        # Push every links of the category
        hrefTitle = "##{normalizeString link.title}"
        links.push(<li className={'active' if link.active} key={link.title} onClick={link.onClick}>
                    <a className='withripple' data-toggle='pill' href={hrefTitle}>{link.title}</a>
                   </li>)

    <div className="panel panel-default" id="sidebar">
      <div className="panel-body">
        <ul className="nav nav-pills nav-stacked">
          {links}
        </ul>
      </div>
    </div>