package net.lab1024.sa.base.common.util;

import jakarta.validation.ConstraintViolation;
import jakarta.validation.Validation;
import jakarta.validation.Validator;
import org.springframework.beans.BeanUtils;

import java.util.Collections;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

/**
 * bean相关工具类
 *
 * @Author 1024创新实验室-主任: 卓大
 * @Date 2018-01-15 10:48:23
 * @Wechat zhuoda1024
 * @Email lab1024@163.com
 * @Copyright <a href="https://1024lab.net">1024创新实验室</a>
 */
public class SmartBeanUtil {

    /**
     * 验证器
     */
    private static final Validator VALIDATOR = Validation.buildDefaultValidatorFactory().getValidator();

    /**
     * 复制bean的属性
     *
     * @param source 源 要复制的对象
     * @param target 目标 复制到此对象
     */
    public static void copyProperties(Object source, Object target) {
        BeanUtils.copyProperties(source, target);
    }

    /**
     * 复制对象
     *
     * @param source 源 要复制的对象
     * @param target 目标 复制到此对象
     * @param <T>    目标对象的类型
     * @return 目标对象
     */
    public static <T> T copy(Object source, Class<T> target) {
        if (source == null || target == null) {
            return null;
        }
        try {
            T newInstance = target.getDeclaredConstructor().newInstance();
            BeanUtils.copyProperties(source, newInstance);
            return newInstance;
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }

    /**
     * 复制list
     *
     * @param source 源 要复制的列表
     * @param target 目标 复制到此对象
     * @param <T>    源列表的类型
     * @param <K>    目标列表的类型
     * @return 目标列表
     */
    public static <T, K> List<K> copyList(List<T> source, Class<K> target) {
        if (null == source || source.isEmpty()) {
            return Collections.emptyList();
        }
        return source.stream().map(e -> copy(e, target)).collect(Collectors.toList());
    }

    /**
     * 手动验证对象 Model 的属性
     * 需要配合 hibernate-validator 校验注解
     *
     * @param t 需要验证的对象
     * @return String 返回 null 代表验证通过，否则返回错误的信息
     */
    public static <T> String verify(T t) {
        // 获取验证结果
        Set<ConstraintViolation<T>> validate = VALIDATOR.validate(t);
        if (validate.isEmpty()) {
            // 验证通过
            return null;
        }
        // 返回错误信息
        List<String> messageList = validate.stream().map(ConstraintViolation::getMessage).toList();
        return messageList.toString();
    }
}
