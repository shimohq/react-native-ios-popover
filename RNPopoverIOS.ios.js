import React, { Component, Children } from 'react';
import PropTypes from 'prop-types';
import {
  NativeEventEmitter,
  NativeModules,
  StyleSheet,
  View,
  Text,
  requireNativeComponent,
  Platform,
  Animated,
  I18nManager
} from 'react-native';

const RNPopoverHostView = requireNativeComponent('RNPopoverHostView');
const RNPopoverHostViewManager = NativeModules.RNPopoverHostViewManager;
const side = I18nManager.isRTL ? 'right' : 'left';

const styles = StyleSheet.create({
  popover: {
    position: 'absolute',
    overflow: 'hidden',
    opacity: 0,
    backgroundColor: 'transparent'
  },
  container: {
    position: 'absolute',
    [side]: 0,
    top: 0
  }
});

export default class extends Component {
  static displayName = 'Popover';
  static propTypes = {
    /**
     * The `visible` prop determines whether your popover is visible.
     */
    visible: PropTypes.bool,
    /**
     * The `animated` prop determines whether present or dismiss popover use animation.
     */
    animated: PropTypes.bool,
    /**
     * The `cancelable` prop determines whether dismiss popover when clicking the out space.
     */
    cancelable: PropTypes.bool,
    /**
     * The `popoverBackgroundColor` prop set popover back ground color. Like '#FFF'
     */
    popoverBackgroundColor: PropTypes.string,
    /**
     * The `sourceViewReactTag` prop is the reactTag of The view containing the anchor rectangle for the popover
     */
    sourceViewReactTag: PropTypes.number,
    /**
     * The `sourceViewTag` prop is the tag of The view containing the anchor rectangle for the popover
     */
    sourceViewTag: PropTypes.number,
    /**
     * The `sourceViewGetterTag` prop is the tag of The view getter which containing the anchor rectangle for the popover
     */
    sourceViewGetterTag: PropTypes.number,
    /**
     * The `sourceViewNativeID` prop is the nativeID of The view containing the anchor rectangle for the popover
     */
    sourceViewNativeID: PropTypes.string,
    /**
     * The `sourceRect` prop is the rectangle in the specified view in which to anchor the popover.
     */
    sourceRect: PropTypes.array,
    /**
     * The arrow directions that you prefer for the popover.
     *
     * 0: up
     * 1: down
     * 2: left
     * 3: right
     *
     * Like [0, 1, 2, 3]
     */
    permittedArrowDirections: PropTypes.array,
    /**
     * The preferred size for the view controller’s view. Like [200, 200]
     */
    preferredContentSize: PropTypes.array,
    /**
     * The `onShow` prop allows passing a function that will be called once the popover has been shown.
     */
    onShow: PropTypes.func,
    /**
     * The `onHide` prop allows passing a function that will be called once the popover has been hidden.
     */
    onHide: PropTypes.func
  };

  static defaultProps = {
    visible: true,
    sourceViewTag: -1,
    sourceViewGetterTag: -1,
    sourceViewReactTag: -1
  };

  static dismiss = (reactTag, animated = true) => {
    return RNPopoverHostViewManager.dismiss(reactTag, animated);
  };

  render() {
    const { visible, children } = this.props;

    if (visible === false) {
      return null;
    }

    return (
      <RNPopoverHostView
        style={styles.popover}
        {...this.props}>
        <View style={styles.container}>
          {children}
        </View>
      </RNPopoverHostView>
    );
  }
}
